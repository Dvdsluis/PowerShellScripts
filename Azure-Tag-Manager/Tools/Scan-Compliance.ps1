<#
.SYNOPSIS
    Azure Environment Tag Compliance Scanner - Modular Version
.DESCRIPTION
    Scans all Azure resources to enforce environment tag compliance with subscription-based policies:
    - Testomgeving subscription: Only dev, test, acc tags allowed
    - All other subscriptions: Only prod tags allowed
    - Only approved tags: prod, dev, acc, test
    - Excludes devops resources from dev classification
    - Supports Dutch environment terms
    
    This modular version provides better maintainability and debugging capabilities.
    
.PARAMETER SubscriptionIds
    Array of subscription IDs to scan. Defaults to all accessible subscriptions.
.PARAMETER Debug
    Enable debug output for detailed analysis.
.EXAMPLE
    .\Scan-EnvTagCompliance-Modular.ps1
.EXAMPLE
    .\Scan-EnvTagCompliance-Modular.ps1 -SubscriptionIds @("12345678-1234-1234-1234-123456789012")
.EXAMPLE
    .\Scan-EnvTagCompliance-Modular.ps1 -Debug
#>
param(
    [string[]] $SubscriptionIds = @(),
    [switch] $Debug,
    [switch] $SuppressWarnings,
    [switch] $UseToBeReviewedFallback
)

# Import required modules
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
Import-Module (Join-Path $ModulePath "Core.psm1") -Force
Import-Module (Join-Path $ModulePath "Policy.psm1") -Force
Import-Module (Join-Path $ModulePath "Detection.psm1") -Force
Import-Module (Join-Path $ModulePath "Scanning.psm1") -Force
Import-Module (Join-Path $ModulePath "Reporting.psm1") -Force
Import-Module (Join-Path $ModulePath "UI.psm1") -Force
Import-Module (Join-Path $ModulePath "Authentication.psm1") -Force

# Main execution
try {
    # Suppress Azure warnings if requested
    if ($SuppressWarnings) {
        Set-AzureWarningPreference
    }
    
    # Display header
    Show-ScriptHeader -Title "Azure Environment Tag Compliance Scanner"
    
    # Check Azure login using enhanced authentication
    if (-not (Test-AzureLoginEnhanced -SuppressWarnings:$SuppressWarnings)) {
        Write-Error "Please login to Azure first using Connect-AzAccount"
        return
    }
    
    $loginInfo = Get-AzureContextSafe -SuppressWarnings:$SuppressWarnings
    if ($loginInfo) {
        $loginData = @{
            IsLoggedIn = $true
            Account = $loginInfo.Account.Id
        }
        if (-not (Show-LoginInfo -LoginInfo $loginData)) {
            return
        }
    } else {
        Write-Error "Unable to get Azure context"
        return
    }
    
    # Create output directory
    $outputDir = "Results\Compliance_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "Results will be saved to: $outputDir" -ForegroundColor Cyan
    
    if ($Debug) {
        Write-Host "Debug mode enabled - detailed output will be shown" -ForegroundColor Magenta
    }
    
    # Get all resources from specified subscriptions
    Write-Host "`nScanning Azure resources..." -ForegroundColor Yellow
    $allResources = Get-AzureResources -SubscriptionIds $SubscriptionIds -Debug:$Debug
    
    if ($allResources.Count -eq 0) {
        Write-Warning "No resources found to scan"
        return
    }
    
    # Group resources by subscription for processing
    $resourcesBySubscription = $allResources | Group-Object SubscriptionName
    $allComplianceResults = @()
    
    Write-Host "`nAnalyzing compliance..." -ForegroundColor Yellow
    
    foreach ($subscriptionGroup in $resourcesBySubscription) {
        $subscriptionName = $subscriptionGroup.Name
        $resources = $subscriptionGroup.Group
        
        Show-ProcessingStatus -SubscriptionName $subscriptionName -IssueCount 0 -PolicyDescription ""
        
        $complianceResults = @()
        $resourceCount = 0
        $totalResources = $resources.Count
        
        foreach ($resource in $resources) {
            $resourceCount++
            
            if ($Debug -and ($resourceCount % 50 -eq 0)) {
                Write-Host "    Processed $resourceCount/$totalResources resources..." -ForegroundColor Gray
            }
            
            try {
                $compliance = Get-ResourceCompliance -Resource $resource -SubscriptionName $subscriptionName -UseToBeReviewedFallback:$UseToBeReviewedFallback
                $complianceResults += $compliance
                
                if ($Debug -and $compliance.Issue) {
                    Write-Host "    Issue found: $($resource.Name) - $($compliance.Issue)" -ForegroundColor Yellow
                }
                
            } catch {
                Write-Warning "Failed to analyze resource $($resource.Name): $($_.Exception.Message)"
                continue
            }
        }
        
        # Generate compliance report for this subscription
        $reportInfo = New-ComplianceReport -ComplianceResults $complianceResults -OutputDirectory $outputDir -SubscriptionName $subscriptionName
        
        # Show summary for this subscription
        $summary = Get-ComplianceSummary -ComplianceResults $complianceResults
        Show-ComplianceSummary -Summary $summary -SubscriptionName $subscriptionName
        
        $allComplianceResults += $complianceResults
        
        Write-Host "  Processed $($resources.Count) resources" -ForegroundColor Green
    }
    
    # Generate overall summary
    Write-Host "`nGenerating overall summary..." -ForegroundColor Yellow
    $summaryFile = New-ScanSummary -AllResults $allComplianceResults -OutputDirectory $outputDir
    
    # Final results
    Write-Host "`n" + ("=" * 60) -ForegroundColor Green
    Write-Host "SCAN COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    
    $totalIssues = ($allComplianceResults | Where-Object { $_.Issue }).Count
    $complianceRate = if ($allComplianceResults.Count -gt 0) { 
        (($allComplianceResults.Count - $totalIssues) / $allComplianceResults.Count) * 100 
    } else { 
        100 
    }
    
    Write-Host "Total Resources Scanned: $($allComplianceResults.Count)" -ForegroundColor White
    Write-Host "Total Issues Found: $totalIssues" -ForegroundColor $(if ($totalIssues -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "Compliance Rate: $([math]::Round($complianceRate, 2))%" -ForegroundColor $(if ($complianceRate -ge 90) { 'Green' } elseif ($complianceRate -ge 70) { 'Yellow' } else { 'Red' })
    Write-Host "Results Location: $outputDir" -ForegroundColor Cyan
    
    if ($totalIssues -gt 0) {
        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "1. Review the CSV reports in: $outputDir" -ForegroundColor White
        Write-Host "2. Run remediation script: .\Apply-EnvTagRemediation-Modular.ps1 -WhatIf" -ForegroundColor White
        Write-Host "3. Apply fixes: .\Apply-EnvTagRemediation-Modular.ps1" -ForegroundColor White
    }
    
} catch {
    Write-Error "Scan execution failed: $($_.Exception.Message)"
    if ($Debug) {
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
} finally {
    if ($Debug) {
        Write-Host "`nDebug: Scan execution completed." -ForegroundColor Magenta
    }
}
