# Function for colored status output
function Write-ColorStatus {
  param (
      [string]$Status,
      [string]$ResourceName,
      [string]$ResourceType
  )
  $message = "[$ResourceType] $ResourceName : $Status"
  switch -Wildcard ($Status) {
      "*✅*" { Write-Host $message -ForegroundColor Green }
      "*❌*" { Write-Host $message -ForegroundColor Red }
      "*⚠️*" { Write-Host $message -ForegroundColor Yellow }
      default { Write-Host $message }
  }
}

# Initialize Azure connection
try {
  Get-AzContext
} catch {
  Connect-AzAccount
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = "NetworkResourcesAudit_$timestamp.csv"
$masterResults = @()
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
  try {
      Set-AzContext -Subscription $sub.Id
      Write-Host "`nChecking subscription: $($sub.Name)" -ForegroundColor Cyan

      # Get all resources
      $nsgs = Get-AzNetworkSecurityGroup
      $asgs = Get-AzApplicationSecurityGroup
      $vnets = Get-AzVirtualNetwork
      $publicIps = Get-AzPublicIpAddress
      $vms = Get-AzVM
      $loadBalancers = Get-AzLoadBalancer
      $appGateways = Get-AzApplicationGateway
      $dnsZones = Get-AzDnsZone
      $nics = Get-AzNetworkInterface

      # Check NSGs
      foreach ($nsg in $nsgs) {
          $status = if ($nsg.Subnets.Count -gt 0 -or $nsg.NetworkInterfaces.Count -gt 0) { "✅ Connected" } else { "❌ Orphaned" }
          Write-ColorStatus -Status $status -ResourceName $nsg.Name -ResourceType "NSG"
          $masterResults += [PSCustomObject]@{
              SubscriptionName = $sub.Name
              ResourceName = $nsg.Name
              ResourceType = "NSG"
              ResourceGroup = $nsg.ResourceGroupName
              Status = $status
              SubnetCount = $nsg.Subnets.Count
              NICCount = $nsg.NetworkInterfaces.Count
          }
      }

      # Check VNets
      foreach ($vnet in $vnets) {
          $connectedSubnets = $vnet.Subnets | Where-Object { $_.IpConfigurations.Count -gt 0 }
          $status = if ($connectedSubnets.Count -gt 0) { "✅ Connected" } else { "❌ Orphaned" }
          Write-ColorStatus -Status $status -ResourceName $vnet.Name -ResourceType "VNet"
          $masterResults += [PSCustomObject]@{
              SubscriptionName = $sub.Name
              ResourceName = $vnet.Name
              ResourceType = "VNet"
              ResourceGroup = $vnet.ResourceGroupName
              Status = $status
              SubnetCount = $vnet.Subnets.Count
              UsedSubnets = $connectedSubnets.Count
          }
      }

      # Check Public IPs
      foreach ($pip in $publicIps) {
          $status = if ($pip.IpConfiguration) { "✅ Connected" } else { "❌ Orphaned" }
          Write-ColorStatus -Status $status -ResourceName $pip.Name -ResourceType "PublicIP"
          $masterResults += [PSCustomObject]@{
              SubscriptionName = $sub.Name
              ResourceName = $pip.Name
              ResourceType = "PublicIP"
              ResourceGroup = $pip.ResourceGroupName
              Status = $status
              IPAddress = $pip.IpAddress
              AssociatedTo = $pip.IpConfiguration.Id
          }
      }

      # Check Load Balancers
      foreach ($lb in $loadBalancers) {
          $status = if ($lb.BackendAddressPools.Count -gt 0) { "✅ Connected" } else { "❌ Orphaned" }
          Write-ColorStatus -Status $status -ResourceName $lb.Name -ResourceType "LoadBalancer"
          $masterResults += [PSCustomObject]@{
              SubscriptionName = $sub.Name
              ResourceName = $lb.Name
              ResourceType = "LoadBalancer"
              ResourceGroup = $lb.ResourceGroupName
              Status = $status
              FrontendCount = $lb.FrontendIpConfigurations.Count
              BackendCount = $lb.BackendAddressPools.Count
          }
      }

      # Check Application Gateways
      foreach ($agw in $appGateways) {
          $status = if ($agw.BackendAddressPools.Count -gt 0) { "✅ Connected" } else { "❌ Orphaned" }
          Write-ColorStatus -Status $status -ResourceName $agw.Name -ResourceType "AppGateway"
          $masterResults += [PSCustomObject]@{
              SubscriptionName = $sub.Name
              ResourceName = $agw.Name
              ResourceType = "AppGateway"
              ResourceGroup = $agw.ResourceGroupName
              Status = $status
              BackendPools = $agw.BackendAddressPools.Count
              State = $agw.OperationalState
          }
      }

  } catch {
      Write-Host "Error processing subscription $($sub.Name): $_" -ForegroundColor Red
  }
}

# Export results
$masterResults | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "`nAudit completed. Results exported to: $outputPath" -ForegroundColor Green
