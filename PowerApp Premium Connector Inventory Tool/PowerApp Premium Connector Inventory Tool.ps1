<#
.SYNOPSIS
    Inventory PowerApps and identify their premium connector usage.

.DESCRIPTION
    This PowerShell script inventories all PowerApps in a specified Power Platform environment,
    downloads each app, and identifies premium connectors used. The results are exported to a CSV file
    for analysis and license management.

.PARAMETER EnvironmentName
    The name of the Power Platform environment to scan. Defaults to "default".

.PARAMETER OutputPath
    The directory path where results will be stored. Defaults to the current directory.

.PARAMETER ExtractApps
    Whether to extract apps for analysis. Set to $false if you only want to scan without extraction.
    Defaults to $true.

.EXAMPLE
    .\PowerApp-Premium-Connector-Inventory.ps1 -EnvironmentName "Contoso (default)"

.EXAMPLE
    .\PowerApp-Premium-Connector-Inventory.ps1 -EnvironmentName "Contoso (default)" -OutputPath "C:\PowerApps-Inventory" -ExtractApps $true

.NOTES
    Requirements:
    - PowerShell 5.1 or later
    - Power Platform CLI (pac) installed and configured
    - Appropriate permissions to access and download PowerApps
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "default",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [bool]$ExtractApps = $true
)

# Script configuration
$ErrorActionPreference = "Stop"
$extractPath = Join-Path -Path $OutputPath -ChildPath "extracted-apps"
$csvPath = Join-Path -Path $OutputPath -ChildPath "PowerApps_PremiumInventory.csv"
$errorLogPath = Join-Path -Path $OutputPath -ChildPath "PowerApps_Inventory_Errors.txt"

# Track errors throughout execution
$errors = @()

# Create output directories if they don't exist
try {
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
        Write-Host "Created directory: $OutputPath" -ForegroundColor Green
    }

    if ($ExtractApps -and !(Test-Path $extractPath)) {
        New-Item -ItemType Directory -Path $extractPath | Out-Null
        Write-Host "Created directory: $extractPath" -ForegroundColor Green
    }
}
catch {
    Write-Error "Failed to create output directories: $_"
    exit 1
}

# Function to check if pac CLI is installed
function Test-PacInstalled {
    try {
        $pacVersion = pac | Select-String -Pattern "Power Platform CLI" -SimpleMatch
        if ($pacVersion) {
            Write-Host "Power Platform CLI found: $pacVersion" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Power Platform CLI not found. Please install it from: https://aka.ms/PowerAppsCLI" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error checking for Power Platform CLI: $_" -ForegroundColor Red
        Write-Host "Please install Power Platform CLI from: https://aka.ms/PowerAppsCLI" -ForegroundColor Red
        return $false
    }
}

# Check if pac is installed
if (!(Test-PacInstalled)) {
    exit 1
}

# Set environment
try {
    Write-Host "Setting environment to '$EnvironmentName'..." -ForegroundColor Cyan
    pac org select --environment $EnvironmentName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to select environment. Ensure the environment name is correct."
    }
}
catch {
    Write-Error "Error setting environment: $_"
    exit 1
}

# Handle authentication
Write-Host "Checking authentication status..." -ForegroundColor Cyan
$authProfiles = pac auth list

if ($authProfiles -match "Active") {
    Write-Host "Authentication profile found" -ForegroundColor Green
    
    # Refresh token if needed
    Write-Host "Refreshing authentication token..." -ForegroundColor Cyan
    pac auth refresh
}
else {
    Write-Host "No active authentication profile found. Creating new authentication profile..." -ForegroundColor Yellow
    
    # Prompt for authentication method
    $authChoice = Read-Host "Select authentication method: [1] Device Code (recommended), [2] Browser"
    
    if ($authChoice -eq "1") {
        pac auth create --deviceCode
    }
    else {
        pac auth create
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create authentication profile. Please run 'pac auth create' manually." -ForegroundColor Red
        exit 1
    }
}

# Define premium connectors
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
    
    # Cloud services
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

# Get app list with error handling
try {
    Write-Host "Retrieving all PowerApps..." -ForegroundColor Cyan
    $jsonOutput = pac canvas list --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing 'pac canvas list': $jsonOutput"
    }

    Write-Host "Successfully retrieved PowerApp list" -ForegroundColor Green
}
catch {
    Write-Host "Error retrieving PowerApps: $_" -ForegroundColor Red
    exit 1
}

# Process the JSON output to get app details
$appsWithIds = @()
try {
    # Handle non-JSON content at the beginning of output
    $jsonStartIndex = $jsonOutput.IndexOf("[")
    if ($jsonStartIndex -ge 0) {
        $cleanJson = $jsonOutput.Substring($jsonStartIndex)
        $jsonEndIndex = $cleanJson.LastIndexOf("]") + 1
        if ($jsonEndIndex -gt 0) {
            $cleanJson = $cleanJson.Substring(0, $jsonEndIndex)
            $apps = $cleanJson | ConvertFrom-Json -ErrorAction Stop
            
            # Process the JSON data
            foreach ($app in $apps) {
                if ($VerbosePreference -eq 'Continue') {
                    Write-Host "Debug - App data:" -ForegroundColor Yellow
                    $app | Format-List
                }
                
                $appsWithIds += @{
                    "name" = $app.name
                    "id" = $app.appId
                    "owner" = if ($app.owner.displayName) { $app.owner.displayName } else { "Unknown" }
                    "lastModified" = if ($app.lastModified) { $app.lastModified } else { "Unknown" }
                }
                Write-Host "Found app: $($app.name) (ID: $($app.appId))" -ForegroundColor Cyan
            }
        } else {
            throw "Invalid JSON format - could not find end bracket"
        }
    } else {
        throw "Invalid JSON format - could not find start bracket"
    }
}
catch {
    Write-Host "JSON parsing failed: $_" -ForegroundColor Yellow
    Write-Host "Falling back to alternative method..." -ForegroundColor Yellow
    $errors += "Warning: JSON parsing failed - $($_)"
}

# If JSON approach didn't work, fall back to using the standard output
if ($appsWithIds.Count -eq 0) {
    Write-Host "Using alternative method to get app details..." -ForegroundColor Yellow
    $appList = pac canvas list
    
    # Skip the header rows
    $appRows = $appList -split "`n" | Select-Object -Skip 2
    
    foreach ($row in $appRows) {
        if ($row.Trim() -ne "") {
            # Extract app name from the row
            $appName = $row.Trim()
            $nameEndPos = $row.IndexOf("  ")
            if ($nameEndPos -gt 0) {
                $appName = $row.Substring(0, $nameEndPos).Trim()
            }
            
            # Try to get detailed info for this app
            Write-Host "Getting details for app: $appName" -ForegroundColor Cyan
            $appDetails = pac canvas show --name "$appName" --output json 2>$null
            $owner = "Unknown"
            $lastModified = "Unknown"
            $appId = $null
            
            if ($appDetails) {
                try {
                    $appData = $appDetails | ConvertFrom-Json
                    $appId = $appData.appId
                    $owner = if ($appData.owner.displayName) { $appData.owner.displayName } else { "Unknown" }
                    $lastModified = if ($appData.lastModified) { $appData.lastModified } else { "Unknown" }
                }
                catch {
                    Write-Host "Could not parse app details: $_" -ForegroundColor Yellow
                }
            }
            
            $safeName = $appName -replace '[\\/:*?"<>|]', '_'
            
            $appsWithIds += @{
                "name" = $appName
                "id" = $appId
                "owner" = $owner
                "lastModified" = $lastModified
                "safeName" = $safeName
            }
            
            Write-Host "Found app: $appName (ID: $appId, Owner: $owner)" -ForegroundColor Cyan
        }
    }
}

if ($appsWithIds.Count -eq 0) {
    Write-Host "No PowerApps found in the current environment." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($appsWithIds.Count) PowerApps. Starting analysis..." -ForegroundColor Green

# Results collection
$results = @()

# Download each app and analyze
foreach ($app in $appsWithIds) {
    $appName = $app.name
    $appId = $app.id
    $owner = $app.owner
    $lastModified = $app.lastModified
    $safeName = if ($app.safeName) { $app.safeName } else { $appName -replace '[\\/:*?"<>|]', '_' }
    
    # Find premium connectors
    $foundConnectors = @()
    $userAccess = "Unknown"
    
    if ($ExtractApps) {
        # Create a folder for each app
        $appFolder = if ($appId) {
            Join-Path $extractPath "${safeName}_${appId}"
        } else {
            Join-Path $extractPath $safeName
        }
        
        if (!(Test-Path $appFolder)) {
            New-Item -ItemType Directory -Path $appFolder | Out-Null
        }
        
        # Download the app - try with ID if available, otherwise use name
        if ($appId) {
            Write-Host "Downloading app: $appName (ID: $appId)" -ForegroundColor Cyan
            $output = pac canvas download --name $appId --extract-to-directory $appFolder --overwrite 2>&1
        } else {
            Write-Host "Downloading app: $appName (using name)" -ForegroundColor Cyan
            $output = pac canvas download --name "$appName" --extract-to-directory $appFolder --overwrite 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Error: Unable to download '$appName'. Make sure you are an owner of the canvas app"
            Write-Warning $errorMsg
            $errors += $errorMsg
        } else {
            Write-Host "Successfully extracted app: $appName to $appFolder" -ForegroundColor Green
            
            # Search through all JSON files for premium connector references
            Get-ChildItem $appFolder -Filter "*.json" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $content = Get-Content $_.FullName -Raw -ErrorAction Stop
                    
                    foreach ($connector in $premiumConnectors) {
                        if ($content -match "(?i)$connector") {
                            if ($foundConnectors -notcontains $connector) {
                                $foundConnectors += $connector
                            }
                        }
                    }
                } catch {
                    Write-Warning "Could not read file: $($_.FullName) - $_"
                }
            }
        }
    }
    
    # Get app permissions (users with access)
    if ($appId) {
        try {
            Write-Host "Getting permissions for app: $appName (ID: $appId)" -ForegroundColor Cyan
            $permissionsJson = pac canvas permissions list --app-id $appId --output json 2>&1
            
            # Parse permissions JSON
            $permStartIndex = $permissionsJson.IndexOf("[")
            if ($permStartIndex -ge 0) {
                $cleanPermJson = $permissionsJson.Substring($permStartIndex)
                $permEndIndex = $cleanPermJson.LastIndexOf("]") + 1
                if ($permEndIndex -gt 0) {
                    $cleanPermJson = $cleanPermJson.Substring(0, $permEndIndex)
                    $permissions = $cleanPermJson | ConvertFrom-Json -ErrorAction Stop
                    
                    # Extract user information
                    $userAccessList = @()
                    foreach ($perm in $permissions) {
                        if ($perm.PrincipalDisplayName) {
                            $userAccessList += "$($perm.PrincipalDisplayName) ($($perm.RoleType))"
                        }
                    }
                    if ($userAccessList.Count -gt 0) {
                        $userAccess = $userAccessList -join ", "
                    } else {
                        $userAccess = "No users with explicit permissions"
                    }
                }
            }
        } catch {
            $userAccess = "Error retrieving permissions: $_"
            $errors += "Warning: Failed to get permissions for app '$appName' - $($_)"
        }
    }
    
    # Add to results
    $results += [PSCustomObject]@{
        AppName = $appName
        AppId = $appId
        Owner = $owner
        LastModified = $lastModified
        UserAccess = $userAccess
        PremiumConnectors = ($foundConnectors -join ", ")
        HasPremium = ($foundConnectors.Count -gt 0)
    }
}

# Export results to CSV
try {
    $results | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Premium connector analysis complete. Results saved to $csvPath" -ForegroundColor Green
}
catch {
    Write-Host "Error exporting results to CSV: $_" -ForegroundColor Red
    $errors += "Error: Failed to export results - $($_)"
}

# Output errors at the end for visibility
if ($errors.Count -gt 0) {
    Write-Host "`n=============== ERRORS SUMMARY ===============" -ForegroundColor Red
    foreach ($errorItem in $errors) {
        Write-Host $errorItem -ForegroundColor Red
    }
    
    # Save errors to file
    try {
        $errors | Out-File $errorLogPath
        Write-Host "Errors saved to $errorLogPath" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Failed to write error log: $_" -ForegroundColor Red
    }
}