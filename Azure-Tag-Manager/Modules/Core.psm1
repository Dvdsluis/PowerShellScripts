<#
.SYNOPSIS
    Core utility functions for Environment Tag Compliance automation
.DESCRIPTION
    Provides shared utility functions for Azure environment tag compliance and remediation
#>

# Test if user is logged into Azure
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

# Get current Azure context information
function Get-AzureLoginInfo {
    try {
        $context = Get-AzContext
        return @{
            IsLoggedIn = $true
            Account = $context.Account.Id
            Subscription = $context.Subscription.Name
            SubscriptionId = $context.Subscription.Id
            Tenant = $context.Tenant.Id
        }
    } catch {
        return @{
            IsLoggedIn = $false
            Account = $null
            Subscription = $null
            SubscriptionId = $null
            Tenant = $null
        }
    }
}

# Find the latest compliance results folder
function Get-LatestComplianceResults {
    param(
        [string]$BasePath = "."
    )
    
    $latestFolder = Get-ChildItem -Path $BasePath -Directory -Name "EnvComplianceResults_*" | 
                   Sort-Object Name -Descending | 
                   Select-Object -First 1
    
    if ($latestFolder) {
        return Join-Path $BasePath $latestFolder
    }
    return $null
}

# Get available compliance reports
function Get-ComplianceReports {
    param(
        [Parameter(Mandatory)]
        [string]$ResultsFolder
    )
    
    if (-not (Test-Path $ResultsFolder)) {
        throw "Results folder not found: $ResultsFolder"
    }
    
    $csvFiles = Get-ChildItem -Path $ResultsFolder -Filter "*_EnvCompliance_*.csv"
    
    $reports = @()
    foreach ($file in $csvFiles) {
        $subscriptionName = $file.Name -replace '_EnvCompliance_.*\.csv$', ''
        $reports += @{
            Name = $subscriptionName
            File = $file.FullName
            LastModified = $file.LastWriteTime
        }
    }
    
    return $reports
}

# Parse confidence from issue text
function Get-ConfidenceFromIssue {
    param(
        [string]$Issue
    )
    
    if ($Issue -match 'confidence: (\d+)%') {
        return [int]$matches[1]
    }
    return 0
}

# Filter issues by confidence threshold
function Get-RemediableIssues {
    param(
        [Parameter(Mandatory)]
        [array]$Issues,
        [int]$MinConfidence = 60
    )
    
    $remediable = @()
    
    foreach ($issue in $Issues) {
        # Skip if no expected tag
        if ([string]::IsNullOrEmpty($issue.ExpectedEnvTag) -or $issue.ExpectedEnvTag -eq "N/A") {
            continue
        }
        
        # Check confidence level
        $confidence = Get-ConfidenceFromIssue -Issue $issue.Issue
        if ($confidence -ge $MinConfidence) {
            $remediable += $issue
        }
    }
    
    return $remediable
}

# Get remediation summary by tag type
function Get-RemediationSummary {
    param(
        [Parameter(Mandatory)]
        [array]$Issues
    )
    
    $summary = @{}
    
    foreach ($issue in $Issues) {
        $tag = $issue.ExpectedEnvTag
        if ($summary.ContainsKey($tag)) {
            $summary[$tag]++
        } else {
            $summary[$tag] = 1
        }
    }
    
    return $summary
}

# Export functions
Export-ModuleMember -Function Test-AzureLogin, Get-AzureLoginInfo, Get-LatestComplianceResults, Get-ComplianceReports, Get-ConfidenceFromIssue, Get-RemediableIssues, Get-RemediationSummary
