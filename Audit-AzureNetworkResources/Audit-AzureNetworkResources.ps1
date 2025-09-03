function Write-Status {
    param (
        [string]$Status,
        [string]$Name,
        [string]$Type
    )
    $msg = "[${Type}] ${Name} : ${Status}"
    switch ($Status) {
        "Connected" { Write-Host $msg -ForegroundColor Green }
        "Orphaned"  { Write-Host $msg -ForegroundColor Red }
        default     { Write-Host $msg }
    }
}

# Ensure Azure context is available
if (-not (Get-AzContext)) {
    Connect-AzAccount | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = "NetworkResourcesAudit_$timestamp.csv"
$results = @()

foreach ($sub in Get-AzSubscription) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Host "`nSubscription: $($sub.Name)" -ForegroundColor Cyan

    $nsgs          = Get-AzNetworkSecurityGroup
    $vnets         = Get-AzVirtualNetwork
    $publicIps     = Get-AzPublicIpAddress
    $loadBalancers = Get-AzLoadBalancer
    $appGateways   = Get-AzApplicationGateway

    foreach ($nsg in $nsgs) {
        $status = if ($nsg.Subnets.Count -gt 0 -or $nsg.NetworkInterfaces.Count -gt 0) { "Connected" } else { "Orphaned" }
        Write-Status $status $nsg.Name "NSG"
        $results += [PSCustomObject]@{
            Subscription = $sub.Name
            Type         = "NSG"
            Name         = $nsg.Name
            Group        = $nsg.ResourceGroupName
            Status       = $status
            Subnets      = $nsg.Subnets.Count
            NICs         = $nsg.NetworkInterfaces.Count
        }
    }

    foreach ($vnet in $vnets) {
        $usedSubnets = ($vnet.Subnets | Where-Object { $_.IpConfigurations.Count -gt 0 }).Count
        $status = if ($usedSubnets -gt 0) { "Connected" } else { "Orphaned" }
        Write-Status $status $vnet.Name "VNet"
        $results += [PSCustomObject]@{
            Subscription = $sub.Name
            Type         = "VNet"
            Name         = $vnet.Name
            Group        = $vnet.ResourceGroupName
            Status       = $status
            TotalSubnets = $vnet.Subnets.Count
            UsedSubnets  = $usedSubnets
        }
    }

    foreach ($pip in $publicIps) {
        $status = if ($pip.IpConfiguration) { "Connected" } else { "Orphaned" }
        Write-Status $status $pip.Name "PublicIP"
        $results += [PSCustomObject]@{
            Subscription = $sub.Name
            Type         = "PublicIP"
            Name         = $pip.Name
            Group        = $pip.ResourceGroupName
            Status       = $status
            IPAddress    = $pip.IpAddress
            LinkedTo     = $pip.IpConfiguration.Id
        }
    }

    foreach ($lb in $loadBalancers) {
        $status = if ($lb.BackendAddressPools.Count -gt 0) { "Connected" } else { "Orphaned" }
        Write-Status $status $lb.Name "LoadBalancer"
        $results += [PSCustomObject]@{
            Subscription = $sub.Name
            Type         = "LoadBalancer"
            Name         = $lb.Name
            Group        = $lb.ResourceGroupName
            Status       = $status
            Frontends    = $lb.FrontendIpConfigurations.Count
            Backends     = $lb.BackendAddressPools.Count
        }
    }

    foreach ($agw in $appGateways) {
        $status = if ($agw.BackendAddressPools.Count -gt 0) { "Connected" } else { "Orphaned" }
        Write-Status $status $agw.Name "AppGateway"
        $results += [PSCustomObject]@{
            Subscription = $sub.Name
            Type         = "AppGateway"
            Name         = $agw.Name
            Group        = $agw.ResourceGroupName
            Status       = $status
            Backends     = $agw.BackendAddressPools.Count
        }
    }
}

# Optional: export results
$results | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "`nAudit complete. Results saved to $outputPath" -ForegroundColor Gray
