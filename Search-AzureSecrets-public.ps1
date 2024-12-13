<#
.SYNOPSIS
  Searches Azure resources for secrets containing specified keywords and generates an inventory.

.DESCRIPTION
  This script searches through Azure Web Apps, Function Apps, and Logic Apps across all accessible 
  subscriptions for secrets or settings containing specified keywords. It searches through app settings
  and configurations, documenting any matches in a specified output file.

.PARAMETER Keywords
  An array of strings to search for in resource settings and configurations.
  Default value is @("InsertKeywordHere")

.PARAMETER OutputFilePath
  The file path where the inventory results will be saved.
  If not specified, defaults to "secrets-inventory.txt" in the script's directory.

.EXAMPLE
  .\Search-AzureSecrets.ps1 -Keywords @("SECRET", "KEY") -OutputFilePath "C:\temp\secrets.txt"
  Searches for "SECRET" and "KEY" in Azure resources and saves results to specified file.

.EXAMPLE
  .\Search-AzureSecrets.ps1
  Searches for default keyword "InsertKeywordHere" and saves to "secrets-inventory.txt" in script directory.

.NOTES
  Prerequisites:
  - Az.Accounts PowerShell module
  - Az.Websites PowerShell module
  - Az.Functions PowerShell module
  - Az.LogicApp PowerShell module
  - Active Azure connection or ability to authenticate

.FUNCTIONALITY
  - Initializes log file for output
  - Connects to Azure if not already connected
  - Processes all enabled subscriptions
  - Searches Web Apps, Function Apps, and Logic Apps in all resource groups
  - Documents findings in specified output file
  - Handles errors gracefully with appropriate warnings

.OUTPUTS
  Creates a text file containing inventory of found secrets with details including:
  - Resource type (WebApp/FunctionApp/LogicApp)
  - Resource name
  - Setting name (if applicable)
  - Matching keyword
#>
#Requires -Modules Az.Accounts, Az.Websites, Az.Functions, Az.LogicApp

[CmdletBinding()]
param (
    [string[]]$Keywords = @("InsertKeywordHere"),
    [string]$OutputFilePath
)

if (-not $OutputFilePath) {
    $OutputFilePath = Join-Path -Path $PSScriptRoot -ChildPath "secrets-inventory.txt"
}

function Initialize-LogFile {
    try {
        $logDir = Split-Path -Path $OutputFilePath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $OutputFilePath -Force | Out-Null
        return $true
    }
    catch {
        Write-Error "Failed to initialize log file: $_"
        return $false
    }
}

function Write-SecretFound {
    param (
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$Setting = '',
        [string]$Keyword
    )

    $settingInfo = if ($Setting) { "setting '$Setting'" } else { "" }
    $message = "[$ResourceType] Secret found in '$ResourceName' $settingInfo containing keyword '$Keyword'"
    Write-Output $message
    Add-Content -Path $OutputFilePath -Value $message
}

function Search-AppSettings {
    param (
        [hashtable]$AppSettings,
        [string]$AppName,
        [string]$ResourceType
    )

    foreach ($keyword in $Keywords) {
        foreach ($setting in $AppSettings.GetEnumerator()) {
            if ($setting.Key -eq $keyword -or $setting.Value -like "*$keyword*") {
                Write-SecretFound -ResourceType $ResourceType -ResourceName $AppName -Setting $setting.Key -Keyword $keyword
                break
            }
        }
    }
}

function Search-WebApp-FunctionApps {
    param (
        [string]$ResourceGroupName,
        [string]$ResourceType
    )

    switch ($ResourceType) {
        'WebApp' {
            Get-AzWebApp -ResourceGroupName $ResourceGroupName | ForEach-Object {
                $app = @{
                    Name = $_.Name
                    Settings = @{}
                }
                $_.SiteConfig.AppSettings | ForEach-Object {
                    $app.Settings[$_.Name] = $_.Value
                }
                $app
            }
        }
        'FunctionApp' {
            Get-AzFunctionApp -ResourceGroupName $ResourceGroupName | ForEach-Object {
                $settings = (Get-AzFunctionAppSetting -ResourceGroupName $ResourceGroupName -Name $_.Name).Properties
                if ($settings) {
                    @{
                        Name = $_.Name
                        Settings = $settings
                    }
                }
            }
        }
    }
}

function Search-LogicApps {
    param ([string]$ResourceGroupName)

    Get-AzLogicApp -ResourceGroupName $ResourceGroupName | ForEach-Object {
        $definitionJson = $_.Definition | ConvertTo-Json -Depth 100
        foreach ($keyword in $Keywords) {
            if ($definitionJson -cmatch $keyword) {
                Write-SecretFound -ResourceType 'LogicApp' -ResourceName $_.Name -Keyword $keyword
                break
            }
        }
    }
}

function Search-ResourceGroup {
    param ([string]$ResourceGroupName)

    foreach ($resourceType in @('WebApp', 'FunctionApp')) {
        try {
            $apps = Get-AppSettings -ResourceGroupName $ResourceGroupName -ResourceType $resourceType
            foreach ($app in $apps) {
                Search-AppSettings -AppSettings $app.Settings -AppName $app.Name -ResourceType $resourceType
            }
        }
        catch {
            Write-Warning "Error processing $resourceType in ${ResourceGroupName}: ${_}"
        }
    }

    try {
        Search-LogicApps -ResourceGroupName $ResourceGroupName
    }
    catch {
        Write-Warning "Error processing Logic Apps in ${ResourceGroupName}: ${_}"
    }
}

try {
    if (-not (Initialize-LogFile)) {
        throw "Failed to initialize log file"
    }

    Write-Output "Starting secrets inventory..."

    if (-not (Get-AzContext)) {
        Connect-AzAccount | Out-Null
    }

    Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' } | ForEach-Object {
        Write-Output "Processing subscription: $($_.Name) ($($_.Id))"
        Select-AzSubscription -SubscriptionId $_.Id | Out-Null

        Get-AzResourceGroup | ForEach-Object {
            Search-ResourceGroup -ResourceGroupName $_.ResourceGroupName
        }
    }

    Write-Output "Inventory complete. Results saved to $OutputFilePath"
}
catch {
    Write-Error "Script execution failed: $_"
}
