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
