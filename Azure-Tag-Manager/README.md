# Azure Tag Manager

**Professional Azure governance solution for automated environment tag compliance scanning and remediation.**

## Overview

Azure Tag Manager provides enterprise-ready tools for enforcing environment tag compliance across Azure subscriptions. It features intelligent environment detection, automated remediation, and comprehensive reporting capabilities.

## Features

- **Smart Environment Detection**: Automatically detects environment types from resource names and existing tags
- **Subscription Policy Enforcement**: Different tag policies per subscription type
- **Modular Architecture**: Clean separation of concerns with testable PowerShell modules
- **Professional Reporting**: Business-ready CSV reports and compliance summaries
- **Safe Remediation**: WhatIf mode and confidence-based filtering
- **Multi-Language Support**: Supports Dutch environment terms

## Repository Structure

```
Azure-Tag-Manager/
├── Azure-TagMenu.ps1                    # Main interactive menu
├── Tools/                               # Core scripts
│   ├── Scan-Compliance.ps1             # Environment compliance scanner
│   └── Apply-Remediation.ps1           # Tag remediation tool
├── Modules/                             # PowerShell modules
│   ├── Authentication.psm1             # Azure authentication
│   ├── Core.psm1                      # Common utilities
│   ├── Detection.psm1                 # Environment detection
│   ├── Policy.psm1                    # Subscription policies
│   ├── Reporting.psm1                 # Report generation
│   ├── Scanning.psm1                  # Resource scanning
│   ├── TagOps.psm1                    # Tag operations
│   └── UI.psm1                        # User interface
├── Results/                            # Generated reports (auto-created)
└── README.md                          # This documentation
```

## Quick Start

### Prerequisites

- Azure PowerShell module (`Install-Module Az`)
- Appropriate Azure permissions (Reader + Tag Contributor)
- PowerShell 5.1 or later

### Installation

1. Clone or download this repository
2. Navigate to the Azure-Tag-Manager directory
3. Run the interactive menu:

```powershell
.\Azure-TagMenu.ps1
```

### Basic Usage

#### Interactive Menu (Recommended)
```powershell
.\Azure-TagMenu.ps1
```

#### Direct Scanning
```powershell
# Basic compliance scan
.\Tools\Scan-Compliance.ps1

# Scan with fallback tagging for unclear resources
.\Tools\Scan-Compliance.ps1 -UseToBeReviewedFallback

# Target specific subscriptions
.\Tools\Scan-Compliance.ps1 -SubscriptionIds @("subscription-id-1", "subscription-id-2")
```

#### Automated Remediation
```powershell
# Preview changes (safe - no actual modifications)
.\Tools\Apply-Remediation.ps1 -WhatIf

# Apply changes with confirmation
.\Tools\Apply-Remediation.ps1 -MinConfidence 80
```

## Environment Tag Standards

### Approved Environment Tags
- `prod` - Production environments
- `dev` - Development environments  
- `test` - Testing environments
- `acc` - Acceptance/staging environments
- `ToBeReviewed` - Resources requiring manual review

### Detection Logic

The system uses a hierarchical confidence-based approach:

1. **Delimited Patterns (95% confidence)**: `app-test-01`, `web-prod-vm`
2. **Dutch Terms (80% confidence)**: `testomgeving`, `productie`
3. **Word Boundaries (60% confidence)**: `testapp`, `prodweb`
4. **Contained Patterns (40% confidence)**: Partial matches within names

## Subscription Policies

### Policy Types
- **Production Subscriptions**: Only `prod` tags allowed
- **Test Subscriptions**: `dev`, `test`, `acc` tags allowed
- **Mixed Subscriptions**: All environment tags allowed

### Policy Configuration

Subscription policies are configured in the `Policy.psm1` module and can be customized based on subscription names or IDs.

## Output and Reporting

### Generated Reports
- **Compliance CSV**: Detailed per-resource compliance status
- **Summary Reports**: High-level compliance statistics
- **Remediation Logs**: Changes applied during remediation

### Report Locations
All reports are saved to timestamped folders in the `Results/` directory:
```
Results/
└── Compliance_YYYYMMDD_HHMMSS/
    ├── SubscriptionName_EnvCompliance_YYYYMMDD_HHMMSS.csv
    └── ScanSummary_YYYYMMDD_HHMMSS.txt
```

## Advanced Configuration

### Custom Environment Detection

Modify `Modules/Detection.psm1` to add custom detection patterns:

```powershell
# Example: Add custom environment terms
$CustomPatterns = @{
    'staging' = @{ Environment = 'acc'; Confidence = 80 }
    'uat' = @{ Environment = 'test'; Confidence = 75 }
}
```

### Subscription Policy Customization

Update `Modules/Policy.psm1` to define subscription-specific policies:

```powershell
# Example: Custom subscription policies
function Get-SubscriptionPolicy {
    param([string]$SubscriptionName)
    
    switch -Wildcard ($SubscriptionName) {
        "*prod*" { return @("prod") }
        "*test*" { return @("dev", "test", "acc") }
        default { return @("prod", "dev", "test", "acc", "ToBeReviewed") }
    }
}
```

## Best Practices

### For Development Teams
- Run compliance scans before major deployments
- Use `-WhatIf` mode to preview changes
- Set minimum confidence levels (80%+) for automated remediation

### For IT Operations
- Schedule regular compliance scans
- Review `ToBeReviewed` tagged resources monthly
- Maintain subscription policy documentation

### For Governance Teams
- Monitor compliance trends over time
- Establish clear environment naming conventions
- Regular policy review and updates

## Troubleshooting

### Common Issues

**Authentication Errors**
```powershell
# Re-authenticate to Azure
Connect-AzAccount
```

**Module Import Errors**
```powershell
# Ensure all modules are present
Get-ChildItem .\Modules\*.psm1
```

**Permission Issues**
- Verify Reader permissions on target subscriptions
- Confirm Tag Contributor role for remediation
- Check conditional access policies

### Debug Mode

Enable verbose output for troubleshooting:
```powershell
.\Tools\Scan-Compliance.ps1 -Debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and feature requests, please create an issue in the GitHub repository.

## Version History

- **v1.0**: Initial release with modular architecture
- **v1.1**: Added ToBeReviewed fallback functionality
- **v1.2**: Enhanced subscription policy enforcement
