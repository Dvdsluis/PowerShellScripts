# PowerApps Premium Connector Inventory Tool

## Overview
This PowerShell tool inventories all PowerApps in a Power Platform environment, identifies premium connectors used, and exports the results to CSV files for analysis. It helps organizations manage license requirements and track app ownership.

## Features
- **Premium Connector Detection**: Detects over 100 premium connectors in PowerApps
- **Role Assignment Tracking**: Documents who has access to each app
- **Owner Information**: Identifies app owners and last modified dates
- **CSV Exports**: Creates structured data for analysis and reporting
- **Enhanced Error Handling**: Reliable execution with comprehensive logging
- **Authentication Options**: Supports different authentication scenarios

## Prerequisites
- PowerShell 5.1 or later
- Power Platform CLI (`pac`) installed
- Appropriate permissions to access and download PowerApps
- Microsoft.PowerApps.Administration.PowerShell module (auto-installed if missing)

## Installation
1. Clone this repository or download the scripts
2. Ensure Power Platform CLI is installed and accessible in your PATH
3. Run the script from PowerShell

## Usage
The tool includes two scripts:

### 1. PowerApps-Premium-Connector-Inventory.ps1
The main script that performs the inventory scan.

```powershell
.\PowerApps-Premium-Connector-Inventory.ps1 -EnvironmentName "Default Environment"
```

#### Parameters
- `-EnvironmentName`: Name of the Power Platform environment to scan
- `-ExtractPath`: Path where app files will be extracted (default: %TEMP%\PowerApps-Extracted)
- `-CsvPath`: Path for the output CSV with premium connector inventory
- `-RoleAssignmentCsvPath`: Path for the output CSV with role assignments
- `-ErrorLogPath`: Path for the error log file
- `-ExportRoleAssignments`: Whether to export role assignments (default: $true)
- `-VerboseDebug`: Enable detailed debugging output
- `-ForceReauthentication`: Force re-authentication to Power Platform
- `-SkipAuthentication`: Skip authentication and use existing credentials

### 2. Run-PowerAppsInventory.ps1
A simplified helper script for common usage scenarios.

```powershell
.\Run-PowerAppsInventory.ps1 -EnvironmentName "Production" -OutputPath "C:\Reports"
```

#### Parameters
- `-EnvironmentName`: Name of the Power Platform environment to scan
- `-SkipAuthentication`: Skip authentication and use existing credentials
- `-ForceReauthentication`: Force re-authentication to Power Platform
- `-OutputPath`: Directory for all output files (extracts, CSVs, logs)

## Output Files
- **PowerApps_PremiumInventory.csv**: Main inventory report with premium connector usage
- **PowerApps_RoleAssignments.csv**: Role assignments for apps and environments
- **PowerApps_Inventory_Errors.txt**: Error log (only created if errors occur)

## Premium Connector Detection
The script checks for over 100 premium connectors including:
- Database connectors (SQL, PostgreSQL, etc.)
- Microsoft services (Dataverse, SharePoint, etc.)
- Azure services (Azure AD, Cognitive Services, etc.) 
- Third-party services (Salesforce, Zendesk, etc.)
- Industry-specific connectors

## Example Output
The premium connector inventory CSV file includes:

| AppName | AppId | Owner | LastModified | UserAccess | PremiumConnectors | HasPremiumConnectors | EnvironmentName | EnvironmentId |
|---------|-------|-------|--------------|------------|-------------------|---------------------|-----------------|---------------|
| Expense App | 12345... | John Smith | 2023-05-01 | User1 (Owner), User2 (Editor) | sql, sharepointonline | True | Production | 67890... |
| HR Portal | 67890... | Jane Doe | 2023-04-15 | User3 (Owner) | None | False | Production | 67890... |

## Troubleshooting
- Ensure you have appropriate permissions in the Power Platform environment
- Check the error log file for detailed error information
- For authentication issues, try running with `-ForceReauthentication`
- Increase the timeout values in the script for very large environments
- For app download issues, ensure sufficient disk space for extracts

## License
MIT License

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request
