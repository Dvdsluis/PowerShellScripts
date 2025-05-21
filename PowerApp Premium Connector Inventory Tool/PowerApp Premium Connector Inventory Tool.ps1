<#
.SYNOPSIS
    Inventory PowerApps premium connector usage with enhanced performance and reliability.
.DESCRIPTION
    This script inventories all PowerApps in a Power Platform environment, identifies premium connectors used,
    and exports the results to CSV files. It also collects and exports role assignments.
    
    This tool helps organizations:
    - Identify which apps require premium licenses
    - Plan license allocation efficiently
    - Maintain compliance with licensing requirements
    - Document app ownership and access rights
.PARAMETER EnvironmentName
    The name of the Power Platform environment to scan.
.PARAMETER ExtractPath
    Path where app files will be extracted. Defaults to a folder in the user's temp directory.
.PARAMETER CsvPath
    Path for the output CSV file with premium connector inventory.
.PARAMETER RoleAssignmentCsvPath
    Path for the output CSV file with role assignments.
.PARAMETER ExportRoleAssignments
    Switch to control whether role assignments should be exported.
.PARAMETER VerboseDebug
    Enable detailed debugging output.
.PARAMETER ForceReauthentication
    Force re-authentication to Power Platform even if already authenticated.
.PARAMETER SkipAuthentication
    Skip the authentication step and assume existing authentication is valid.
.EXAMPLE
    .\PowerApps-Premium-Connector-Inventory.ps1 -EnvironmentName "Default Environment"
    
    Runs the inventory on the specified environment using default paths for outputs.
.EXAMPLE
    .\PowerApps-Premium-Connector-Inventory.ps1 -EnvironmentName "Production" -ExtractPath "C:\Temp\PowerApps" -CsvPath "C:\Reports\Premium-Connectors.csv"
    
    Runs the inventory with custom paths for extracted apps and the output CSV.
.EXAMPLE
    .\PowerApps-Premium-Connector-Inventory.ps1 -SkipAuthentication -VerboseDebug
    
    Runs the inventory with detailed logging and skips authentication (assumes you're already authenticated).
.NOTES
    Version: 2.1
    Last Update: 2023-06-01
    Author: GitHub Community
    License: MIT
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "Default Environment",
    
    [Parameter(Mandatory = $false)]
    [string]$ExtractPath = "$env:TEMP\PowerApps-Extracted",
    
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "$PSScriptRoot\PowerApps_PremiumInventory.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$RoleAssignmentCsvPath = "$PSScriptRoot\PowerApps_RoleAssignments.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$ErrorLogPath = "$PSScriptRoot\PowerApps_Inventory_Errors.txt",
    
    [Parameter(Mandatory = $false)]
    [switch]$ExportRoleAssignments = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseDebug = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceReauthentication = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAuthentication = $false
)

#region Functions

# Function to log messages to console and error list
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO", # INFO, WARNING, ERROR, DEBUG, SUCCESS
        [object]$Exception = $null # Accept any error type
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    if ($Exception) {
        # Handle both Exception and ErrorRecord objects
        if ($Exception -is [System.Management.Automation.ErrorRecord]) {
            $logEntry += " | Exception: $($Exception.Exception.Message)"
            if ($Exception.ScriptStackTrace) {
                $logEntry += " | StackTrace: $($Exception.ScriptStackTrace)"
            }
        }
        else {
            # Original behavior for System.Exception objects
            $logEntry += " | Exception: $($Exception.Message)"
            if ($Exception.StackTrace) {
                $logEntry += " | StackTrace: $($Exception.StackTrace)"
            }
        }
    }

    # Console output
    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor Cyan }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "DEBUG"   { if ($VerboseDebug) { Write-Host $logEntry -ForegroundColor Gray } }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }

    # Add to errors array for summary and file logging
    if ($Level -in @("WARNING", "ERROR")) {
        $script:errors += $logEntry
    }
}

# Function to check and install PowerShell modules
function EnsureModuleInstalled {
    param (
        [string]$ModuleName
    )
    
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log "Installing $ModuleName module..." "WARNING"
        try {
            Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser
            Import-Module -Name $ModuleName -ErrorAction Stop
            Write-Log "$ModuleName module installed and imported successfully" "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to install $ModuleName module" "ERROR" $_
            return $false
        }
    }
    else {
        try {
            Import-Module -Name $ModuleName -ErrorAction Stop
            Write-Log "$ModuleName module imported successfully" "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to import $ModuleName module" "ERROR" $_
            return $false
        }
    }
}

# Function to authenticate to Power Platform
function Initialize-PowerPlatformAuthentication {
    param (
        [switch]$ForceReauthentication = $false
    )

    Write-Log "Checking authentication status..." "INFO"
    $authProfiles = pac auth list 2>&1

    if ($VerboseDebug) {
        Write-Log "Auth profiles:" "DEBUG"
        Write-Log ($authProfiles | Out-String) "DEBUG"
    }

    # Check if profile exists and is active, or create a new one
    $isAuthenticated = $false
    if ($authProfiles -match "Active" -and -not $ForceReauthentication) {
        Write-Log "Authentication profile found and active" "SUCCESS"
        
        # Test if the authentication is still valid by running a simple command
        $testAuth = pac org list 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Authentication is valid, skipping re-authentication" "SUCCESS"
            $isAuthenticated = $true
            return $true
        }
        
        Write-Log "Authentication appears to be expired or invalid, will re-authenticate" "WARNING"
    }
    
    # We need to authenticate, either because no profile exists or we're forcing reauthentication
    if ($authProfiles -match "Active" -and ($ForceReauthentication -or $LASTEXITCODE -ne 0)) {
        Write-Log "Clearing existing authentication profile..." "WARNING"
        pac auth clear
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Warning: Could not clear authentication profile, but proceeding with new authentication" "WARNING"
        }
    }
    
    # Try to authenticate with device code first (safer in automated scripts)
    Write-Log "Creating new authentication profile using device code flow..." "INFO"
    Write-Log "Please follow the instructions to authenticate in your browser when prompted" "INFO"
    
    # Try device code authentication first with timeout
    $authResult = Invoke-CommandWithTimeout -Command "pac" -Arguments @("auth", "create", "--deviceCode") -TimeoutSeconds 90 -Description "Device code authentication"
    
    if ($authResult.TimedOut -or $authResult.ExitCode -ne 0) {
        if ($authResult.TimedOut) {
            Write-Log "Device code authentication timed out after 90 seconds." "WARNING"
        } else {
            Write-Log "Device code authentication failed with exit code: $($authResult.ExitCode)" "WARNING"
            Write-Log "Error details: $($authResult.Error)" "DEBUG"
        }
        
        Write-Log "Trying interactive authentication instead..." "WARNING"
        
        # Try interactive authentication with timeout
        $authResult = Invoke-CommandWithTimeout -Command "pac" -Arguments @("auth", "create") -TimeoutSeconds 120 -Description "Interactive authentication"
        
        if ($authResult.TimedOut -or $authResult.ExitCode -ne 0) {
            if ($authResult.TimedOut) {
                Write-Log "Interactive authentication timed out after 120 seconds." "ERROR"
            } else {
                Write-Log "Interactive authentication failed with exit code: $($authResult.ExitCode)" "ERROR"
                Write-Log "Error details: $($authResult.Error)" "ERROR"
            }
            
            Write-Log "Authentication failed. Please run 'pac auth create' manually and try again." "ERROR"
            return $false
        }
    }
    
    # Verify authentication was successful
    $authProfiles = pac auth list 2>&1
    if ($authProfiles -match "Active") {
        Write-Log "Authentication successful" "SUCCESS"
        return $true
    } else {
        Write-Log "Authentication verification failed. Active profile not found." "ERROR"
        return $false
    }
}

# Function to set up and validate the Power Platform environment
function Set-PowerPlatformEnvironment {
    param (
        [string]$EnvironmentName
    )
    
    try {
        # Get available environments
        Write-Log "Getting environment list..." "INFO"
        $envCommand = "pac org list"
        $envResult = Invoke-Expression $envCommand 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to get environment list. Error: $envResult" "ERROR"
            Write-Log "Make sure you're authenticated to Power Platform CLI" "ERROR"
            return $null
        }
        
        if ($VerboseDebug) {
            Write-Log "Environment list output:" "DEBUG"
            Write-Log ($envResult | Out-String) "DEBUG"
        }
        
        # Parse environments
        $environments = @()
        $currentEnv = $null
        $foundEnvId = $null
        
        # Initialize data collection
        $collectingData = $false
        $headers = @()
        $envDataRows = @()
        
        # Process each line
        foreach ($line in $envResult) {
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Start of table
            if ($line -match "^----" -and -not $collectingData) {
                $collectingData = $true
                continue
            }
            
            # Headers line
            if ($collectingData -and $headers.Count -eq 0) {
                $headers = $line -split '\s\s+' | ForEach-Object { $_.Trim() }
                continue
            }
            
            # Data lines
            if ($collectingData -and $headers.Count -gt 0) {
                if ($line -match "^----") { 
                    $collectingData = $false
                    continue
                }
                
                $dataRow = $line -split '\s\s+' | ForEach-Object { $_.Trim() }
                $envObject = [PSCustomObject]@{}
                
                for ($i = 0; $i -lt $headers.Count -and $i -lt $dataRow.Count; $i++) {
                    Add-Member -InputObject $envObject -MemberType NoteProperty -Name $headers[$i] -Value $dataRow[$i]
                }
                
                $environments += $envObject
            }
        }
        
        Write-Log "Found $($environments.Count) environments" "SUCCESS"
        
        if ($environments.Count -eq 0) {
            Write-Log "No environments found. Exiting script." "ERROR"
            return $null
        }
        
        # Find the specified environment
        $selectedEnv = $environments | Where-Object { $_.DisplayName -like "*$EnvironmentName*" }
        
        if (-not $selectedEnv) {
            Write-Log "Environment '$EnvironmentName' not found. Available environments:" "ERROR"
            $environments | ForEach-Object { 
                Write-Log "  - $($_.DisplayName)" "INFO"
            }
            
            # Ask user to select an environment if the input doesn't match
            Write-Log "Please provide a valid environment name from the list above and try again." "ERROR"
            return $null
        }
        
        if ($selectedEnv.Count -gt 1) {
            Write-Log "Multiple environments found matching '$EnvironmentName'. Please be more specific:" "WARNING"
            $selectedEnv | ForEach-Object { 
                Write-Log "  - $($_.DisplayName)" "INFO"
            }
            return $null
        }
        
        # Select environment
        $envDisplayName = $selectedEnv.DisplayName
        $envId = $selectedEnv.EnvironmentId
        
        Write-Log "Setting current environment to: $envDisplayName ($envId)" "INFO"
        $selectResult = pac org select --environment $envId 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to select environment: $selectResult" "ERROR"
            return $null
        }
        
        Write-Log "Environment '$envDisplayName' selected successfully" "SUCCESS"
        return @{
            DisplayName = $envDisplayName
            Id = $envId
        }
    }
    catch {
        Write-Log "Error setting up environment" "ERROR" $_
        return $null
    }
}

# Function to get PowerApps using CLI
function Get-PowerAppsUsingCLI {
    Write-Log "Getting PowerApps using CLI..." "INFO"
    
    try {
        # Get all apps using JSON format first for more reliable parsing
        $appsWithJson = Invoke-CommandWithTimeout -Command "pac" -Arguments @("canvas", "list", "--json") -TimeoutSeconds 120 -Description "PowerApps CLI list (JSON format)"
        
        if ($appsWithJson.TimedOut) {
            Write-Log "Command timed out while getting apps using JSON format, trying standard format..." "WARNING"
        }
        elseif ($appsWithJson.ExitCode -eq 0 -and $appsWithJson.Output) {
            try {
                $appsData = $appsWithJson.Output | ConvertFrom-Json
                $allApps = @()
                
                foreach ($app in $appsData) {
                    # Generate a safe file name
                    $safeName = $app.name -replace '[\\/:*?"<>|]', '_'
                    
                    $allApps += [PSCustomObject]@{
                        name = $app.name
                        id = $app.appId
                        safeName = $safeName
                        owner = $app.owner.displayName
                        lastModified = $app.lastModifiedTime
                    }
                }
                
                Write-Log "Successfully retrieved $($allApps.Count) apps using JSON format" "SUCCESS"
                return @{
                    apps = $allApps
                    isJsonOutput = $true
                }
            }
            catch {
                Write-Log "Error parsing JSON output from PowerApps CLI" "ERROR" $_
                # Fall through to try standard format
            }
        }
        
        # If JSON format fails or times out, try standard format
        $appsCommand = Invoke-CommandWithTimeout -Command "pac" -Arguments @("canvas", "list") -TimeoutSeconds 120 -Description "PowerApps CLI list (standard format)"
        
        if ($appsCommand.TimedOut) {
            Write-Log "Command timed out while getting apps, this might result in incomplete data" "ERROR"
            return @{
                apps = @()
                isJsonOutput = $false
            }
        }
        
        if ($appsCommand.ExitCode -ne 0) {
            Write-Log "Failed to get apps: $($appsCommand.Error)" "ERROR"
            return @{
                apps = @()
                isJsonOutput = $false
            }
        }
        
        # Parse output manually
        $output = $appsCommand.Output -split "`n"
        $apps = @()
        $currentApp = $null
        $collectingData = $false
        $headers = @()
        
        foreach ($line in $output) {
            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            # Detect table start
            if ($line -match "^----" -and -not $collectingData) {
                $collectingData = $true
                continue
            }
            
            # Headers line
            if ($collectingData -and $headers.Count -eq 0) {
                $headers = $line -split '\s\s+' | ForEach-Object { $_.Trim() }
                continue
            }
            
            # Data lines
            if ($collectingData -and $headers.Count -gt 0) {
                if ($line -match "^----") { 
                    $collectingData = $false
                    continue
                }
                
                $appData = $line -split '\s\s+' | ForEach-Object { $_.Trim() }
                
                if ($appData.Count -ge 3) {
                    $appName = $appData[0]
                    $safeName = $appName -replace '[\\/:*?"<>|]', '_'
                    
                    $appInfo = [PSCustomObject]@{
                        name = $appName
                        id = $appData[1]
                        safeName = $safeName
                        owner = if ($appData.Count -gt 3) { $appData[2] } else { "Unknown" }
                        lastModified = if ($appData.Count -gt 4) { $appData[3] } else { "Unknown" }
                    }
                    
                    $apps += $appInfo
                }
            }
        }
        
        Write-Log "Successfully retrieved $($apps.Count) apps using standard format" "SUCCESS"
        return @{
            apps = $apps
            isJsonOutput = $false
        }
    }
    catch {
        Write-Log "Error getting apps" "ERROR" $_
        return @{
            apps = @()
            isJsonOutput = $false
        }
    }
}

# Function to get PowerApps using PowerShell module if CLI fails
function Get-PowerAppsUsingPowerShell {
    try {
        Write-Log "Getting PowerApps using PowerShell module..." "INFO"
        
        # Ensure module is installed
        $moduleInstalled = EnsureModuleInstalled "Microsoft.PowerApps.Administration.PowerShell"
        if (-not $moduleInstalled) {
            return @()
        }
        
        # Get environment
        $environments = Get-AdminPowerAppEnvironment
        $environment = $environments | Where-Object { $_.DisplayName -like "*$EnvironmentName*" }
        
        if (-not $environment) {
            Write-Log "Environment '$EnvironmentName' not found using PowerShell module" "ERROR"
            return @()
        }
        
        $envId = $environment.EnvironmentName
        
        # Get apps
        $apps = Get-AdminPowerApp -EnvironmentName $envId
        
        if (-not $apps -or $apps.Count -eq 0) {
            Write-Log "No PowerApps found in environment using PowerShell module" "WARNING"
            return @()
        }
        
        $allApps = $apps | ForEach-Object {
            $safeName = $_.DisplayName -replace '[\\/:*?"<>|]', '_'
            
            [PSCustomObject]@{
                name = $_.DisplayName
                id = $_.AppName
                safeName = $safeName
                owner = $_.Owner.displayName
                lastModified = $_.LastModifiedTime
            }
        }
        
        Write-Log "Successfully retrieved $($allApps.Count) apps using PowerShell module" "SUCCESS"
        return $allApps
    }
    catch {
        Write-Log "Error getting apps using PowerShell module" "ERROR" $_
        return @()
    }
}

# Function to get role assignments
function Get-PowerAppRoleAssignments {
    param (
        [string]$EnvironmentName,
        [string]$RoleAssignmentCsvPath
    )
    
    $roleAssignmentModuleReady = $false
    $roleAssignmentCollection = @()
    $global:allRoleAssignments = @()
    
    try {
        Write-Log "Getting role assignments..." "INFO"
        
        # Ensure module is installed
        $moduleInstalled = EnsureModuleInstalled "Microsoft.PowerApps.Administration.PowerShell"
        if (-not $moduleInstalled) {
            return @{
                "isReady" = $false
                "assignments" = @()
                "globalAssignments" = @()
            }
        }
        
        # Get environment
        $environments = Get-AdminPowerAppEnvironment
        $environment = $environments | Where-Object { $_.DisplayName -like "*$EnvironmentName*" }
        
        if ($environment) {
            $envDisplayName = $environment.DisplayName
            $envId = $environment.EnvironmentName
            
            Write-Log "Found environment '$envDisplayName' ($envId)" "SUCCESS"
            
            # Get environment-level role assignments
            try {
                $envRoleAssignments = Get-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $envId
                
                if ($envRoleAssignments) {
                    $global:allRoleAssignments += $envRoleAssignments
                    
                    foreach ($role in $envRoleAssignments) {
                        $roleAssignmentCollection += [PSCustomObject]@{
                            EnvironmentName = $envDisplayName
                            EnvironmentId = $envId
                            AppName = "N/A"
                            AppId = "N/A"
                            PrincipalDisplayName = $role.PrincipalDisplayName
                            PrincipalEmail = $role.PrincipalEmail
                            PrincipalObjectId = $role.PrincipalObjectId
                            PrincipalType = $role.PrincipalType
                            RoleName = $role.RoleName
                            AssignmentType = "Environment"
                        }
                    }
                    
                    Write-Log "Found $($envRoleAssignments.Count) environment-level role assignments" "DEBUG"
                }
            }
            catch {
                Write-Log "Could not get environment-level role assignments" "WARNING" $_
            }
            
            # Get app-level role assignments
            try {
                # Get all apps
                $allApps = Get-AdminPowerApp -EnvironmentName $envId
                
                if ($allApps -and $allApps.Count -gt 0) {
                    $appCount = $allApps.Count
                    $currentApp = 0
                    
                    foreach ($app in $allApps) {
                        $currentApp++
                        $progressPercent = [math]::Round(($currentApp / $appCount) * 100)
                        Write-Progress -Activity "Processing app role assignments" -Status "$currentApp of $appCount - $($app.DisplayName)" -PercentComplete $progressPercent
                        
                        try {
                            $appRoleAssignments = Get-AdminPowerAppRoleAssignment -EnvironmentName $envId -AppName $app.AppName
                            
                            if ($appRoleAssignments) {
                                $global:allRoleAssignments += $appRoleAssignments
                                
                                # Add to our role collection for export
                                foreach ($role in $appRoleAssignments) {
                                    $roleAssignmentCollection += [PSCustomObject]@{
                                        EnvironmentName = $envDisplayName
                                        EnvironmentId = $envId  
                                        AppName = $app.DisplayName
                                        AppId = $app.AppName
                                        PrincipalDisplayName = $role.PrincipalDisplayName
                                        PrincipalEmail = $role.PrincipalEmail
                                        PrincipalObjectId = $role.PrincipalObjectId
                                        PrincipalType = $role.PrincipalType
                                        RoleName = $role.RoleName
                                        AssignmentType = "App"
                                    }
                                }
                                Write-Log "Found $($appRoleAssignments.Count) role assignments for $($app.DisplayName)" "DEBUG"
                            }
                            # Don't overwhelm the service with requests
                            Start-Sleep -Milliseconds 50
                        }
                        catch {
                            Write-Log "Could not get role assignments for app $($app.DisplayName)" "WARNING" $_
                        }
                    }
                    Write-Progress -Activity "Processing app role assignments" -Completed
                    
                    $roleAssignmentModuleReady = $true
                    Write-Log "Successfully retrieved $($roleAssignmentCollection.Count) total role assignments" "SUCCESS"
                    
                    # Export role assignments if requested
                    if ($ExportRoleAssignments -and $roleAssignmentCollection.Count -gt 0) {
                        try {
                            $roleAssignmentCollection | Export-Csv -Path $RoleAssignmentCsvPath -NoTypeInformation
                            Write-Log "Role assignments exported to $RoleAssignmentCsvPath" "SUCCESS"
                        } catch {
                            Write-Log "Failed to export role assignments" "ERROR" $_
                        }
                    }
                } else {
                    Write-Log "No apps found in environment for role assignments" "WARNING"
                }
            } else {
                Write-Log "Could not find environment for role assignments" "WARNING"
            }
        }
    } catch {
        Write-Log "Failed to get all role assignments - will try per app" "WARNING" $_
    }
    
    return @{
        "isReady" = $roleAssignmentModuleReady
        "assignments" = $roleAssignmentCollection
        "globalAssignments" = $global:allRoleAssignments
    }
}

# Function to get app permissions
function Get-PowerAppPermissions {
    param (
        [string]$AppName,
        [string]$AppId,
        [string]$EnvironmentName,
        [bool]$RoleAssignmentModuleReady,
        [array]$RoleAssignmentCollection,
        [array]$GlobalRoleAssignments
    )
    
    $userAccess = "Unknown"
    
    try {
        Write-Log "Getting permissions for app: $AppName (ID: $AppId)" "INFO"
        
        # Look in our already collected role assignments first
        if ($RoleAssignmentModuleReady -and $RoleAssignmentCollection.Count -gt 0) {
            # Get app-specific role assignments
            $appSpecificRoles = $RoleAssignmentCollection | Where-Object { $_.AppId -eq $AppId }
            
            # Get environment-level roles that might affect this app
            $envRoles = $RoleAssignmentCollection | Where-Object { $_.AssignmentType -eq "Environment" }
            
            # Combine both sets
            $effectiveRoles = @()
            $effectiveRoles += $appSpecificRoles
            $effectiveRoles += $envRoles
            
            if ($effectiveRoles.Count -gt 0) {
                $userAccessList = @()
                foreach ($role in $effectiveRoles) {
                    $userAccessList += "$($role.PrincipalDisplayName) ($($role.RoleName))"
                }
                $userAccess = $userAccessList -join ", "
            }
        }
        
        # If we couldn't determine user access from cached role assignments, try directly
        if ($userAccess -eq "Unknown" -or $userAccess -eq "") {
            try {
                # Ensure module is installed
                if (EnsureModuleInstalled "Microsoft.PowerApps.Administration.PowerShell") {
                    try {
                        # Get app-specific role assignments
                        $appRoleAssignments = Get-AdminPowerAppRoleAssignment -EnvironmentName $EnvironmentName -AppName $AppId -ErrorAction SilentlyContinue
                        
                        if ($appRoleAssignments -and $appRoleAssignments.Count -gt 0) {
                            $userAccessList = @()
                            foreach ($role in $appRoleAssignments) {
                                $userAccessList += "$($role.PrincipalDisplayName) ($($role.RoleName))"
                            }
                            $userAccess = $userAccessList -join ", "
                        }
                    } catch {
                        Write-Log "Could not get role assignments for app $AppName" "DEBUG" $_
                    }
                }
            } catch {
                Write-Log "Error getting permissions using PowerShell module" "DEBUG" $_
            }
        }
    } catch {
        Write-Log "Error getting permissions for app $AppName" "WARNING" $_
    }
    
    return $userAccess
}

# Function to detect premium connectors in app files
function Find-PremiumConnectors {
    param (
        [string]$AppFolder,
        [array]$PremiumConnectors
    )
    
    $foundConnectors = @()
    
    # Search through all JSON files for premium connector references
    Get-ChildItem $AppFolder -Filter "*.json" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $content = Get-Content $_.FullName -Raw -ErrorAction Stop
            foreach ($connector in $PremiumConnectors) {
                if ($content -match "(?i)$connector") {
                    if ($foundConnectors -notcontains $connector) {
                        $foundConnectors += $connector
                    }
                }
            }
        } catch {
            Write-Log "Could not read file: $($_.FullName)" "WARNING" $_
        }
    }
    
    return $foundConnectors
}

# Function to run a command with a timeout
function Invoke-CommandWithTimeout {
    param (
        [string]$Command,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 60,
        [string]$Description = "Command"
    )
    
    Write-Log "Running $Description (Timeout: ${TimeoutSeconds}s)..." "DEBUG"
    
    try {
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $Command
        $processStartInfo.Arguments = $Arguments -join " "
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        
        # Create string builders to capture output and error
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder
        
        # Set up event handlers for output
        $outputHandler = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        }
        
        $errorHandler = {
            if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                $Event.MessageData.AppendLine($EventArgs.Data)
            }
        }
        
        # Register event handlers
        $outputEvent = Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action $outputHandler -MessageData $outputBuilder
        $errorEvent = Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action $errorHandler -MessageData $errorBuilder
        
        # Start the process
        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # Wait for the process to exit or timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            Write-Log "$Description timed out after $TimeoutSeconds seconds" "WARNING"
            try {
                $process.Kill()
            } catch {
                Write-Log "Error killing process: $($_.Exception.Message)" "WARNING"
            }
            return @{
                Output = $outputBuilder.ToString()
                Error = $errorBuilder.ToString()
                ExitCode = -1
                TimedOut = $true
            }
        }
        
        # Ensure all output is processed
        $process.WaitForExit()
        
        # Clean up event handlers
        Unregister-Event -SourceIdentifier $outputEvent.Name
        Unregister-Event -SourceIdentifier $errorEvent.Name
        
        # Return results
        return @{
            Output = $outputBuilder.ToString()
            Error = $errorBuilder.ToString()
            ExitCode = $process.ExitCode
            TimedOut = $false
        }
    }
    catch {
        Write-Log "Error executing ${Description}: $($_.Exception.Message)" "ERROR" $_
        return @{
            Output = ""
            Error = $_.Exception.Message
            ExitCode = -1
            TimedOut = $false
        }
    }
}
#endregion Functions

#region Main Script

# Initialize errors array
$script:errors = @()

# Script start timestamp
$scriptStartTime = Get-Date
Write-Log "PowerApp Premium Connector Inventory Tool started at $($scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"

# Create directory for extracted apps if it doesn't exist
if (!(Test-Path $ExtractPath)) {
    New-Item -ItemType Directory -Path $ExtractPath | Out-Null
    Write-Log "Created directory: $ExtractPath" "SUCCESS"
}

# Authenticate to Power Platform (unless explicitly skipped)
if (-not $SkipAuthentication) {
    Write-Log "Authenticating to Power Platform..." "INFO"
    $isAuthenticated = Initialize-PowerPlatformAuthentication -ForceReauthentication:$ForceReauthentication
    if (-not $isAuthenticated) {
        Write-Log "Failed to authenticate to Power Platform. Exiting script." "ERROR"
        exit 1
    }
} else {
    Write-Log "Authentication step skipped as requested. Assuming existing authentication is valid." "WARNING"
    $isAuthenticated = $true
}

# Set up environment
$environmentObj = Set-PowerPlatformEnvironment -EnvironmentName $EnvironmentName
if ($null -eq $environmentObj) {
    exit 1
}
$EnvironmentName = $environmentObj.Id
$EnvironmentDisplayName = $environmentObj.DisplayName

# Get apps using pac CLI
$appsInfo = Get-PowerAppsUsingCLI
$appsWithIds = $appsInfo.apps

# If no apps found through CLI, try PowerShell module as fallback
if ($appsWithIds.Count -eq 0) {
    Write-Log "No apps found using CLI, trying PowerShell module..." "WARNING"
    $appsWithIds = Get-PowerAppsUsingPowerShell
}

if ($appsWithIds.Count -eq 0) {
    Write-Log "No PowerApps found in environment. Exiting script." "ERROR"
    exit 1
}

Write-Log "Found $($appsWithIds.Count) PowerApps in environment '$EnvironmentDisplayName'" "SUCCESS"

# List of premium connectors to check for
$premiumConnectors = @(
    # Database connectors
    "sql", "sqlserver", "postgresql", "mysql", "oracle", "db2", "informix", "impala", 

    # Microsoft services
    "commondataservice", "commondata", "dataverse", "powerappsforadmins", "powerappsformakers",
    "sharepoint", "sharepointonline", "office365", "office365users", "office365groups", 
    "excel", "excelonline", "excelonlinebusiness", "onedrive", "onedriveforbusiness",
    "outlooktasks", "projectonline", "dynamicssmbsaas", "dynamics365", "dynamicsax",
    "dynamics365businesscentral", "dynamics365salesinsights", "dynamicscrm",
    "dynamics365customerinsights", "dynamics365financials", "dynamicsnavonline",
    
    # Azure connectors
    "azuread", "azureblob", "azurestorage", "azuretables", "azurequeues", "azurefile",
    "documentdb", "cosmosdb", "cognitiveservicescomputervision", "cognitiveservicestext",
    "servicebus", "datafactory", "azureautomation", "logicappsmanagement",
    "apimanagement", "eventgrid", "keyvault", "azuredevops", "azureevent",
    
    # Third-party services
    "salesforce", "marketo", "mailchimp", "servicenow", "zendesk", "jira", "github",
    "googlecalendar", "googledrive", "googletasks", "googlesheets", "box", "dropbox",
    "docusign", "amazonaws", "awss3", "hubspot", "docparser", "webmerge",
    "oracleeloqua", "quickbase", "adobecreativecloud", "adobemarketo", "odata",
    "ibmpush", "slack", "asana", "zoho", "woocommerce", "smtp", "trello",
    "surveymonkey", "stripe", "paypal", "twitter", "parserr", "plumsail",

    # Integration connectors
    "http", "https", "ftp", "sftp", "soap", "webdataconnector", "xmlvalidation",
    "xmltransformation", "customapi", "customconnector", "aibuilder",
    
    # Industry specific
    "medicalimaging", "healthdata", "sapsuccess", "sapodatav2", "sapodatav4",
    "sapehr", "saperp", "siemensmindsphere"
)

# Get role assignments
$roleAssignmentsInfo = Get-PowerAppRoleAssignments -EnvironmentName $EnvironmentName -RoleAssignmentCsvPath $RoleAssignmentCsvPath
$roleAssignmentModuleReady = $roleAssignmentsInfo.isReady
$roleAssignmentCollection = $roleAssignmentsInfo.assignments
$allRoleAssignments = $roleAssignmentsInfo.globalAssignments

# Results collection
$results = @()

# Process each app
foreach ($app in $appsWithIds) {
    $appName = $app.name
    $appId = $app.id
    $owner = $app.owner
    $lastModified = $app.lastModified
    $safeName = $app.safeName
    
    # Create a folder for each app
    $appFolder = if ($appId -and $appId -ne "Unknown") {
        Join-Path -Path $ExtractPath -ChildPath "$safeName-$appId"
    } else {
        Join-Path -Path $ExtractPath -ChildPath $safeName
    }
    
    if (!(Test-Path $appFolder)) {
        New-Item -ItemType Directory -Path $appFolder | Out-Null
    }
    
    Write-Log "Processing app: $appName (ID: $appId)" "INFO"
    
    try {
        # Download and extract the app
        $pacArgs = @("canvas", "export", "--path", $appFolder)
        
        # Add app-id parameter if available
        if ($appId -and $appId -ne "Unknown") {
            $pacArgs += "--app-id"
            $pacArgs += $appId
        }
        
        $downloadResult = Invoke-CommandWithTimeout -Command "pac" -Arguments $pacArgs -TimeoutSeconds 180 -Description "Download app $appName"
        
        if ($downloadResult.TimedOut) {
            Write-Log "Timed out downloading app $appName" "WARNING"
            continue
        }
        
        if ($downloadResult.ExitCode -ne 0) {
            Write-Log "Failed to download app $appName - Error: $($downloadResult.Error)" "WARNING"
            continue
        }
        
        Write-Log "Successfully downloaded app $appName" "SUCCESS"
        
        # Find premium connectors in app files
        $foundConnectors = Find-PremiumConnectors -AppFolder $appFolder -PremiumConnectors $premiumConnectors
        
        # Get user access info
        $userAccess = Get-PowerAppPermissions -AppName $appName -AppId $appId -EnvironmentName $EnvironmentName `
                        -RoleAssignmentModuleReady $roleAssignmentModuleReady `
                        -RoleAssignmentCollection $roleAssignmentCollection `
                        -GlobalRoleAssignments $allRoleAssignments
        
        # Add to results
        $appResult = [PSCustomObject]@{
            AppName = $appName
            AppId = $appId
            Owner = $owner
            LastModified = $lastModified
            UserAccess = $userAccess
            PremiumConnectors = if ($foundConnectors.Count -gt 0) { $foundConnectors -join ", " } else { "None" }
            HasPremiumConnectors = if ($foundConnectors.Count -gt 0) { $true } else { $false }
            EnvironmentName = $EnvironmentDisplayName
            EnvironmentId = $EnvironmentName
        }
        
        $results += $appResult
        
        Write-Log "App $appName processed. Premium connectors found: $(if ($foundConnectors.Count -gt 0) { $foundConnectors -join ", " } else { "None" })" "SUCCESS"
    } catch {
        Write-Log "Error processing app $appName" "ERROR" $_
    }
}

# Export results to CSV
if ($results.Count -gt 0) {
    try {
        $results | Export-Csv -Path $CsvPath -NoTypeInformation
        Write-Log "Results exported to $CsvPath" "SUCCESS"
    } catch {
        Write-Log "Failed to export results to CSV" "ERROR" $_
    }
} else {
    Write-Log "No results to export" "WARNING"
}

# Write any errors to file
if ($script:errors.Count -gt 0) {
    try {
        $script:errors | Out-File -FilePath $ErrorLogPath
        Write-Log "$($script:errors.Count) errors logged to $ErrorLogPath" "WARNING"
    } catch {
        Write-Log "Failed to write errors to log file" "ERROR" $_
    }
}

# Print summary
$scriptEndTime = Get-Date
$scriptDuration = $scriptEndTime - $scriptStartTime

Write-Log "PowerApp Premium Connector Inventory Tool completed in $($scriptDuration.TotalMinutes.ToString("0.00")) minutes" "SUCCESS"
Write-Log "Total PowerApps processed: $($results.Count)" "INFO"
Write-Log "PowerApps with premium connectors: $(($results | Where-Object { $_.HasPremiumConnectors }).Count)" "INFO"
Write-Log "PowerApps without premium connectors: $(($results | Where-Object { -not $_.HasPremiumConnectors }).Count)" "INFO"
#endregion Main Script
