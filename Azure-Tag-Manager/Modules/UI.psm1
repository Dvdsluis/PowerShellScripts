<#
.SYNOPSIS
    User interface functions for Environment Tag Compliance automation
.DESCRIPTION
    Handles user interaction, menus, and display formatting
#>

# Display script header
function Show-ScriptHeader {
    param(
        [string]$Title = "Azure Environment Tag Auto-Remediation Script",
        [string]$Color = "Cyan"
    )
    
    Write-Host $Title -ForegroundColor $Color
    Write-Host ("=" * $Title.Length) -ForegroundColor $Color
}

# Display Azure login information
function Show-LoginInfo {
    param(
        [Parameter(Mandatory)]
        [hashtable]$LoginInfo
    )
    
    if ($LoginInfo.IsLoggedIn) {
        Write-Host "Logged in as: $($LoginInfo.Account)" -ForegroundColor Green
    } else {
        Write-Error "Please login to Azure first using Connect-AzAccount"
        return $false
    }
    return $true
}

# Display subscription selection menu
function Show-SubscriptionMenu {
    param(
        [Parameter(Mandatory)]
        [array]$Subscriptions
    )
    
    Write-Host "`nAvailable subscriptions from compliance reports:" -ForegroundColor Yellow
    Write-Host ("=" * 49) -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $Subscriptions.Count; $i++) {
        Write-Host "[$($i + 1)] $($Subscriptions[$i].Name)" -ForegroundColor White
    }
    Write-Host "[A] Process ALL subscriptions" -ForegroundColor Green
    Write-Host "[Q] Quit" -ForegroundColor Red
}

# Get user subscription selection
function Get-SubscriptionSelection {
    param(
        [Parameter(Mandatory)]
        [array]$Subscriptions
    )
    
    do {
        $selection = Read-Host "Select subscription(s) to process (number, A for all, Q to quit)"
        
        if ($selection -eq "Q" -or $selection -eq "q") {
            return $null
        }
        
        if ($selection -eq "A" -or $selection -eq "a") {
            return $Subscriptions
        }
        
        if ($selection -match '^\d+$') {
            $index = [int]$selection - 1
            if ($index -ge 0 -and $index -lt $Subscriptions.Count) {
                return @($Subscriptions[$index])
            }
        }
        
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    } while ($true)
}

# Display processing status
function Show-ProcessingStatus {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionName,
        [int]$IssueCount = 0,
        [string]$PolicyDescription = ""
    )
    
    Write-Host "`nProcessing subscription: $SubscriptionName" -ForegroundColor Yellow
    Write-Host " + " -NoNewline; Write-Host ("=" * 60) -ForegroundColor Gray
    Write-Host "Processing: $SubscriptionName" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    if ($IssueCount -gt 0) {
        Write-Host "Found $IssueCount issues in compliance report" -ForegroundColor Gray
    }
    
    if ($PolicyDescription) {
        Write-Host $PolicyDescription -ForegroundColor Gray
    }
}

# Display policy violation with red formatting
function Show-PolicyViolation {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Violation
    )
    
    Write-Host "  POLICY VIOLATION: $($Violation.ResourceName)" -ForegroundColor Red
    Write-Host "    $($Violation.Message)" -ForegroundColor Red
    Write-Host "    $($Violation.Details)" -ForegroundColor Red
    if ($Violation.Issue) {
        Write-Host "    Reason: $($Violation.Issue)" -ForegroundColor DarkRed
    }
}

# Display tag update result
function Show-TagUpdateResult {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Result,
        [string]$Reason = "",
        [switch]$WhatIf
    )
    
    if ($Result.Success) {
        if ($WhatIf) {
            Write-Host "  WOULD UPDATE: $($Result.ResourceName)" -ForegroundColor Yellow
            Write-Host "    Current Environment Tag: $($Result.CurrentTag)" -ForegroundColor Gray
            Write-Host "    New Environment Tag: $($Result.NewTag)" -ForegroundColor Green
            if ($Reason) {
                Write-Host "    Reason: $Reason" -ForegroundColor Gray
            }
        } else {
            Write-Host "  UPDATING: $($Result.ResourceName)" -ForegroundColor Green
            Write-Host "    ✓ Applied Environment tag: $($Result.NewTag)" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✗ Failed to process $($Result.ResourceName): $($Result.Error)" -ForegroundColor Red
        if ($Result.Error -like "*api-version*") {
            Write-Host "    This resource type may require a specific API version for tag updates" -ForegroundColor Yellow
        }
    }
}

# Display remediation summary
function Show-RemediationSummary {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Summary,
        [switch]$WhatIf
    )
    
    Write-Host "`nRemediation Summary:" -ForegroundColor Yellow
    foreach ($tag in $Summary.Keys | Sort-Object) {
        Write-Host "  $tag`: $($Summary[$tag]) resources" -ForegroundColor White
    }
}

# Display final summary
function Show-FinalSummary {
    param(
        [int]$TotalProcessed = 0,
        [int]$TotalApplied = 0,
        [int]$TotalSkipped = 0,
        [switch]$WhatIf
    )
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Green
    Write-Host "REMEDIATION SUMMARY" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    
    Write-Host "Total issues processed: $TotalProcessed" -ForegroundColor White
    
    if ($WhatIf) {
        Write-Host "Total changes that would be made: $TotalApplied" -ForegroundColor Yellow
        Write-Host "Total skipped: $TotalSkipped" -ForegroundColor Gray
        Write-Host "Run without -WhatIf to apply changes" -ForegroundColor Green
    } else {
        Write-Host "Total changes applied: $TotalApplied" -ForegroundColor Green
        Write-Host "Total skipped: $TotalSkipped" -ForegroundColor Gray
    }
}

# Export functions
Export-ModuleMember -Function Show-ScriptHeader, Show-LoginInfo, Show-SubscriptionMenu, Get-SubscriptionSelection, Show-ProcessingStatus, Show-PolicyViolation, Show-TagUpdateResult, Show-RemediationSummary, Show-FinalSummary
