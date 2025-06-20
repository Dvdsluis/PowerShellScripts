<#
.SYNOPSIS
    Azure Environment Tag Auto-Remediation Script - Modular Version
.DESCRIPTION
    Automatically applies environment tags based on compliance scan results and subscription policies:
    - Testomgeving subscription: Only dev, test, acc tags allowed
    - All other subscriptions: Only prod tags allowed
    - Only applies approved tags: prod, dev, acc, test
    - Supports WhatIf mode for preview
    - Confidence-based filtering to avoid false positives
    
    This modular version provides better maintainability and debugging capabilities.
    
.PARAMETER ResultsFolder
    Path to folder containing compliance scan CSV files. Defaults to latest results folder.
.PARAMETER MinConfidence
    Minimum confidence level (%) for auto-remediation. Default is 60%.
.PARAMETER WhatIf
    Preview changes without applying them.
.PARAMETER Debug
    Enable detailed debug output.
.EXAMPLE
    .\Apply-EnvTagRemediation-Modular.ps1 -WhatIf
.EXAMPLE
    .\Apply-EnvTagRemediation-Modular.ps1 -MinConfidence 80
.EXAMPLE
    .\Apply-EnvTagRemediation-Modular.ps1 -Debug -WhatIf
#>
param(
    [string] $ResultsFolder = "",
    [int] $MinConfidence = 60,
    [switch] $WhatIf,
    [switch] $Debug,
    [switch] $SuppressWarnings
)

# Import required modules
$ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
Import-Module (Join-Path $ModulePath "Core.psm1") -Force
Import-Module (Join-Path $ModulePath "Policy.psm1") -Force
Import-Module (Join-Path $ModulePath "TagOps.psm1") -Force
Import-Module (Join-Path $ModulePath "UI.psm1") -Force
Import-Module (Join-Path $ModulePath "Authentication.psm1") -Force

# Main script execution
try {
    # Suppress Azure warnings if requested
    if ($SuppressWarnings) {
        Set-AzureWarningPreference
    }
    
    # Display header
    Show-ScriptHeader
    
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
    
    Write-Host "Minimum confidence threshold: $MinConfidence%" -ForegroundColor Gray
    
    # Find results folder
    if ([string]::IsNullOrEmpty($ResultsFolder)) {
        $ResultsFolder = Get-LatestComplianceResults
        if (-not $ResultsFolder) {
            Write-Error "No compliance results folder found. Please run the compliance scan first."
            return
        }
        Write-Host "Auto-detected latest results folder: $(Split-Path $ResultsFolder -Leaf)" -ForegroundColor Green
    }
    
    # Get compliance reports
    try {
        $reports = Get-ComplianceReports -ResultsFolder $ResultsFolder
        Write-Host "Found $($reports.Count) compliance reports" -ForegroundColor Green
    } catch {
        Write-Error "Failed to read compliance reports: $($_.Exception.Message)"
        return
    }
    
    # Show subscription selection menu
    Show-SubscriptionMenu -Subscriptions $reports
    $selectedSubscriptions = Get-SubscriptionSelection -Subscriptions $reports
    
    if (-not $selectedSubscriptions) {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        return
    }
    
    # Initialize counters
    $totalProcessed = 0
    $totalApplied = 0
    $totalSkipped = 0
    
    # Process each selected subscription
    foreach ($sub in $selectedSubscriptions) {
        try {
            # Read compliance data
            $issues = Import-Csv -Path $sub.File
            
            # Get subscription policy
            $policy = Get-SubscriptionPolicy -SubscriptionName $sub.Name
            
            # Display processing status
            Show-ProcessingStatus -SubscriptionName $sub.Name -IssueCount $issues.Count -PolicyDescription $policy.Description
            
            # Set Azure subscription context
            $azSub = Get-AzSubscription | Where-Object { $_.Name -like "*$($sub.Name)*" } | Select-Object -First 1
            if (-not $azSub) {
                Write-Warning "Could not find Azure subscription matching '$($sub.Name)'"
                continue
            }
              Write-Host "Setting context to subscription: $($sub.Name) ($($azSub.Id))" -ForegroundColor Gray
            if (-not (Set-AzureSubscriptionSafe -SubscriptionId $azSub.Id -SuppressWarnings:$SuppressWarnings)) {
                Write-Warning "Failed to set subscription context for '$($sub.Name)'"
                continue
            }
            
            # Filter remediable issues
            $remediableIssues = Get-RemediableIssues -Issues $issues -MinConfidence $MinConfidence
            Write-Host "Found $($remediableIssues.Count) auto-remediable issues" -ForegroundColor Green
            
            if ($remediableIssues.Count -eq 0) {
                Write-Host "No remediable issues found for this subscription." -ForegroundColor Gray
                continue
            }
            
            # Show remediation summary
            $summary = Get-RemediationSummary -Issues $remediableIssues
            Show-RemediationSummary -Summary $summary
            
            # Display mode message
            if ($WhatIf) {
                Write-Host "`n[WHAT-IF MODE] Showing changes that would be made:" -ForegroundColor Yellow
            } else {
                Write-Host "`nApplying environment tags..." -ForegroundColor Green
            }
            
            # Process each issue
            foreach ($issue in $remediableIssues) {
                $totalProcessed++
                
                # Check subscription policy
                if (-not (Test-TagAllowed -Tag $issue.ExpectedEnvTag -SubscriptionName $sub.Name)) {
                    $violation = Get-PolicyViolation -Tag $issue.ExpectedEnvTag -SubscriptionName $sub.Name -ResourceName $issue.ResourceName -Issue $issue.Issue
                    Show-PolicyViolation -Violation $violation
                    $totalSkipped++
                    continue
                }
                
                # Apply or preview tag change
                try {
                    $result = Set-EnvironmentTag -ResourceName $issue.ResourceName -ResourceType $issue.ResourceType -EnvironmentTag $issue.ExpectedEnvTag -WhatIf:$WhatIf
                    
                    Show-TagUpdateResult -Result $result -Reason $issue.Issue -WhatIf:$WhatIf
                    
                    if ($result.Success -and $result.Action -eq "Applied") {
                        $totalApplied++
                    } elseif ($result.Success -and $result.Action -eq "WhatIf") {
                        $totalApplied++  # Count as "would apply"
                    } else {
                        $totalSkipped++
                    }
                    
                } catch {
                    Write-Host "  ✗ Failed to process $($issue.ResourceName): $($_.Exception.Message)" -ForegroundColor Red
                    if ($_.Exception.Message -like "*api-version*") {
                        Write-Host "    This resource type may require a specific API version for tag updates" -ForegroundColor Yellow
                    }
                    $totalSkipped++
                }
                
                # Small delay to avoid throttling
                Start-Sleep -Milliseconds 100
            }
            
        } catch {
            Write-Warning "Failed to process subscription '$($sub.Name)': $($_.Exception.Message)"
            continue
        }
        
        Write-Host " + " -NoNewline; Write-Host ("=" * 60) -ForegroundColor Gray
    }
    
    # Display final summary
    Show-FinalSummary -TotalProcessed $totalProcessed -TotalApplied $totalApplied -TotalSkipped $totalSkipped -WhatIf:$WhatIf
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    if ($Debug) {
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
} finally {
    # Clean up modules if needed
    if ($Debug) {
        Write-Host "`nDebug: Script execution completed." -ForegroundColor Magenta
    }
}
