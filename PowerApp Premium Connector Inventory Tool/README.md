# PowerApp Premium Connector Inventory Tool

A PowerShell script to inventory PowerApps in a Power Platform environment and identify premium connector usage.

## Features

- Automatically scans all PowerApps in a specified environment
- Identifies premium connector usage in each app
- Downloads and extracts app contents for in-depth analysis
- Reports on app ownership, last modified date, and user access
- Generates a detailed CSV report for license management

## Requirements

- PowerShell 5.1 or later
- [Power Platform CLI](https://aka.ms/PowerAppsCLI) installed and configured
- Appropriate permissions to access and download PowerApps
- Windows, macOS, or Linux with PowerShell

## Installation

1. Download the script from this repository
2. Ensure Power Platform CLI is installed (`pac` command is available)
3. Run the script with appropriate parameters

## Usage

```powershell
.\PowerApp-Premium-Connector-Inventory.ps1 -EnvironmentName "YourEnvironment" -OutputPath "C:\YourOutputPath" -ExtractApps $true
```

### Parameters

- **EnvironmentName**: The name of your Power Platform environment (default: "default")
- **OutputPath**: Directory to store results and extracted apps (default: current directory)
- **ExtractApps**: Whether to extract and analyze app contents (default: $true)

## Output

The script generates:

- A CSV report with all PowerApps and their premium connector usage
- Downloaded app files (optional) for in-depth analysis
- Error log file for troubleshooting

## Example CSV Output

| AppName | AppId | Owner | LastModified | UserAccess | PremiumConnectors | HasPremium |
|---------|-------|-------|-------------|------------|-------------------|------------|
| Inventory App | 12345abc | Jane Doe | 2023-05-15 | John Smith (Owner), Team A (User) | sql, sharepoint | TRUE |
| Simple Form | 67890def | John Smith | 2023-04-20 | Team B (User) | | FALSE |

## License

MIT

## Contributing

Contributions welcome! Please submit a pull request or open an issue.