<#
.SYNOPSIS
    Report generation for Environment Tag Compliance scanning
.DESCRIPTION
    Handles CSV export, summary reporting, and compliance metrics
#>

# Create compliance report from analysis results
function New-ComplianceReport {
    param(
        [Parameter(Mandatory)]
        [array]$ComplianceResults,
        [Parameter(Mandatory)]
        [string]$OutputDirectory,
        [Parameter(Mandatory)]
        [string]$SubscriptionName
    )
    
    # Create CSV filename
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "$($SubscriptionName)_EnvCompliance_$timestamp.csv"
    $filepath = Join-Path $OutputDirectory $filename
    
    # Export to CSV
    $ComplianceResults | Export-Csv -Path $filepath -NoTypeInformation -Encoding UTF8
    
    Write-Host "  Report saved: $filename" -ForegroundColor Green
    
    return @{
        FilePath = $filepath
        FileName = $filename
        RecordCount = $ComplianceResults.Count
    }
}

# Generate summary statistics for compliance results
function Get-ComplianceSummary {
    param(
        [Parameter(Mandatory)]
        [array]$ComplianceResults
    )
    
    $summary = @{
        TotalResources = $ComplianceResults.Count
        NoIssues = 0
        MissingTags = 0
        InvalidTags = 0
        PolicyViolations = 0
        ByPriority = @{
            HIGH = 0
            MEDIUM = 0
            LOW = 0
        }
        ByEnvironment = @{
            prod = 0
            dev = 0
            test = 0
            acc = 0
            unknown = 0
        }
    }
    
    foreach ($result in $ComplianceResults) {
        # Count by issue type
        switch ($result.IssueType) {
            "No Issue" { $summary.NoIssues++ }
            "Missing Environment Tag" { $summary.MissingTags++ }
            "Invalid Environment Tag" { $summary.InvalidTags++ }
            "Policy Violation" { $summary.PolicyViolations++ }
        }
        
        # Count by priority
        if ($summary.ByPriority.ContainsKey($result.Priority)) {
            $summary.ByPriority[$result.Priority]++
        }
        
        # Count by detected environment
        $env = if ($result.DetectedEnv -and $result.DetectedEnv -ne "N/A") { 
            $result.DetectedEnv.ToLower() 
        } else { 
            "unknown" 
        }
        
        if ($summary.ByEnvironment.ContainsKey($env)) {
            $summary.ByEnvironment[$env]++
        } else {
            $summary.ByEnvironment["unknown"]++
        }
    }
    
    return $summary
}

# Display compliance summary with formatting
function Show-ComplianceSummary {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary,
        [Parameter(Mandatory)]
        [string]$SubscriptionName
    )
    
    Write-Host "`n  Compliance Summary for $SubscriptionName" -ForegroundColor Cyan
    Write-Host "  " + ("=" * 50) -ForegroundColor Cyan
    
    Write-Host "  Total Resources: $($Summary.TotalResources)" -ForegroundColor White
    Write-Host "  No Issues: $($Summary.NoIssues)" -ForegroundColor Green
    Write-Host "  Missing Tags: $($Summary.MissingTags)" -ForegroundColor Yellow
    Write-Host "  Invalid Tags: $($Summary.InvalidTags)" -ForegroundColor Red
    Write-Host "  Policy Violations: $($Summary.PolicyViolations)" -ForegroundColor Red
    
    Write-Host "`n  Priority Breakdown:" -ForegroundColor Yellow
    Write-Host "    HIGH: $($Summary.ByPriority.HIGH)" -ForegroundColor Red
    Write-Host "    MEDIUM: $($Summary.ByPriority.MEDIUM)" -ForegroundColor Yellow
    Write-Host "    LOW: $($Summary.ByPriority.LOW)" -ForegroundColor Gray
    
    Write-Host "`n  Environment Distribution:" -ForegroundColor Yellow
    Write-Host "    Production: $($Summary.ByEnvironment.prod)" -ForegroundColor Green
    Write-Host "    Development: $($Summary.ByEnvironment.dev)" -ForegroundColor Blue
    Write-Host "    Test: $($Summary.ByEnvironment.test)" -ForegroundColor Cyan
    Write-Host "    Acceptance: $($Summary.ByEnvironment.acc)" -ForegroundColor Magenta
    Write-Host "    Unknown: $($Summary.ByEnvironment.unknown)" -ForegroundColor Gray
}

# Create overall scan summary
function New-ScanSummary {
    param(
        [Parameter(Mandatory)]
        [array]$AllResults,
        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $summaryFile = Join-Path $OutputDirectory "ScanSummary_$timestamp.txt"
    
    $content = @()
    $content += "Azure Environment Tag Compliance Scan Summary"
    $content += "=" * 50
    $content += "Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $content += ""
    
    # Group by subscription
    $bySubscription = $AllResults | Group-Object SubscriptionName
    
    $content += "Subscription Summary:"
    $content += "-" * 20
    
    $totalIssues = 0
    foreach ($group in $bySubscription) {
        $subSummary = Get-ComplianceSummary -ComplianceResults $group.Group
        $issues = $subSummary.TotalResources - $subSummary.NoIssues
        $totalIssues += $issues
        
        $content += "$($group.Name): $($subSummary.TotalResources) resources, $issues issues"
    }
    
    $content += ""
    $content += "Overall Statistics:"
    $content += "-" * 18
    $content += "Total Resources Scanned: $($AllResults.Count)"
    $content += "Total Issues Found: $totalIssues"
    $content += "Compliance Rate: $('{0:P2}' -f (($AllResults.Count - $totalIssues) / $AllResults.Count))"
    
    $content | Out-File -FilePath $summaryFile -Encoding UTF8
    Write-Host "Scan summary saved: $(Split-Path $summaryFile -Leaf)" -ForegroundColor Green
    
    return $summaryFile
}

# Export functions
Export-ModuleMember -Function New-ComplianceReport, Get-ComplianceSummary, Show-ComplianceSummary, New-ScanSummary
