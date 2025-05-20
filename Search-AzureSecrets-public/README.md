
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

---

### Azure Network Resource Audit Tool

#### SYNOPSIS
Audits Azure network resources across all subscriptions to identify orphaned and unused components.

#### DESCRIPTION
This PowerShell script performs comprehensive network resource auditing:

1. **Resource Types Audited**
   - Network Security Groups (NSGs)
   - Virtual Networks (VNets)
   - Application Security Groups (ASGs)
   - Public IP Addresses
   - Load Balancers
   - Application Gateways
   - DNS Zones
   - Network Interfaces (NICs)

2. **Functionality**
   - Scans all subscriptions
   - Checks resource connectivity
   - Identifies orphaned resources
   - Validates resource configurations
   - Color-coded status output
   - CSV export of findings

#### PREREQUISITES
- Az PowerShell module
- Azure account with appropriate permissions
- PowerShell 5.1 or higher

#### PARAMETERS
None - Script runs against all accessible subscriptions

#### USAGE
```powershell
.\Audit-AzureNetworkResources.ps1
```

#### OUTPUT
- Console: Color-coded resource status
- CSV file: Detailed audit results with timestamp
  - Resource details
  - Connection status
  - Configuration counts
  - Resource relationships

#### EXAMPLE OUTPUT
```
[NSG] myNSG-prod : ✅ Connected
[VNet] myVNet-prod : ✅ Connected
[PublicIP] unused-ip : ❌ Orphaned
```

#### CSV FIELDS
- SubscriptionName
- ResourceName
- ResourceType
- ResourceGroup
- Status
- Additional type-specific details

#### NOTE
Script requires appropriate RBAC permissions across subscriptions for resource auditing.
