<#
.SYNOPSIS
    Azure Environment Tag Compliance - Unified Menu System
.DESCRIPTION
    Main entry point for Azure Environment Tag Compliance automation.
    Provides a unified menu to access scanning, remediation, and reporting functions.
    
    Features:
    - Interactive menu system
    - Modular architecture with better debugging
    - Comprehensive environment tag compliance management
    - Subscription policy enforcement
    - Confidence-based recommendations
    
.PARAMETER AutoScan
    Automatically run a full scan without menu interaction.
.PARAMETER AutoRemediate
    Automatically run remediation in WhatIf mode without menu interaction.
.PARAMETER Debug
    Enable debug mode for detailed output.
.EXAMPLE
    .\EnvTag-Menu.ps1
.EXAMPLE
    .\EnvTag-Menu.ps1 -AutoScan
.EXAMPLE
    .\EnvTag-Menu.ps1 -AutoRemediate -Debug
#>
param(
    [switch] $AutoScan,
    [switch] $AutoRemediate,
    [switch] $Debug
)

# Import core utilities
$ModulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $ModulePath "Core.psm1") -Force
Import-Module (Join-Path $ModulePath "UI.psm1") -Force

# Main menu function
function Show-MainMenu {
    Clear-Host
    
    Write-Host "`n"
    Write-Host "                         Azure Tag Manager" -ForegroundColor Cyan
    Write-Host "                   Environment Tag Compliance Suite" -ForegroundColor White
    
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "                   AZURE ENVIRONMENT TAG COMPLIANCE AUTOMATION" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Cyan
      # Check Azure login status
    $loginInfo = Get-AzureLoginInfo
    if ($loginInfo.IsLoggedIn) {
        Write-Host "[✓] Connected to Azure as: $($loginInfo.Account)" -ForegroundColor Green
        Write-Host "    Current Subscription: $($loginInfo.Subscription)" -ForegroundColor Gray
    } else {
        Write-Host "[!] Not logged into Azure" -ForegroundColor Red
        Write-Host "    Please run: Connect-AzAccount" -ForegroundColor Yellow
    }
    
    # Show latest results info
    $latestResults = Get-LatestComplianceResults
    if ($latestResults) {
        $resultFolder = Split-Path $latestResults -Leaf
        Write-Host "[i] Latest scan results: $resultFolder" -ForegroundColor Blue
    } else {
        Write-Host "[i] No previous scan results found" -ForegroundColor Yellow
    }
    
    Write-Host "`n" + ("─" * 80) -ForegroundColor Gray
    Write-Host "                                MAIN MENU" -ForegroundColor Yellow
    Write-Host ("─" * 80) -ForegroundColor Gray
      Write-Host "`n[1] Scan Environment Tag Compliance" -ForegroundColor White
    Write-Host "    Analyze all Azure resources for environment tag compliance" -ForegroundColor Gray
    
    Write-Host "`n[2] Remediate Environment Tags" -ForegroundColor White  
    Write-Host "    Apply environment tags based on scan results (with preview)" -ForegroundColor Gray
    
    Write-Host "`n[3] View Latest Scan Results" -ForegroundColor White
    Write-Host "    Review compliance reports and statistics" -ForegroundColor Gray
    
    Write-Host "`n[4] Advanced Options" -ForegroundColor White
    Write-Host "    Custom scans, specific subscriptions, debug mode" -ForegroundColor Gray
    
    Write-Host "`n[5] Help & Documentation" -ForegroundColor White
    Write-Host "    Usage guides, best practices, troubleshooting" -ForegroundColor Gray
    
    Write-Host "`n[Q] Quit" -ForegroundColor Red
    
    Write-Host "`n" + ("─" * 80) -ForegroundColor Gray
    
    return Read-Host "`nSelect an option (1-5, Q)"
}

# Advanced options menu
function Show-AdvancedMenu {
    Clear-Host
    Write-Host "ADVANCED OPTIONS" -ForegroundColor Cyan
    Write-Host ("=" * 30) -ForegroundColor Cyan
    
    Write-Host "`n[1] Scan Specific Subscriptions" -ForegroundColor White
    Write-Host "[2] Remediate with Custom Confidence" -ForegroundColor White
    Write-Host "[3] 🐛 Debug Mode Scan" -ForegroundColor White
    Write-Host "[4] 🐛 Debug Mode Remediation" -ForegroundColor White
    Write-Host "[5] Custom Reports" -ForegroundColor White
    Write-Host "[B] Back to Main Menu" -ForegroundColor Gray
    
    return Read-Host "`nSelect an option (1-5, B)"
}

# Help menu
function Show-HelpMenu {
    Clear-Host
    Write-Host "HELP & DOCUMENTATION" -ForegroundColor Cyan
    Write-Host ("=" * 30) -ForegroundColor Cyan
    
    Write-Host @"

📘 QUICK START GUIDE
─────────────────────
1. Login to Azure: Connect-AzAccount
2. Run compliance scan: Select option [1]
3. Review results in generated CSV files
4. Preview fixes: Select option [2] 
5. Apply fixes after review

SUBSCRIPTION POLICIES
────────────────────────
• Test Subscriptions (contains 'test'): Only dev, test, acc tags allowed
• Production Subscriptions: Only prod tags allowed
• Policy violations are highlighted in RED

APPROVED ENVIRONMENT TAGS
──────────────────────────────
• prod (production)
• dev (development)  
• test (testing)
• acc (acceptance)

CONFIDENCE LEVELS
────────────────────
• 95%: Delimited patterns (app-test-01)
• 80%: Dutch terms (testomgeving)
• 60%: Contained patterns (testapp)
• 40%: Location-based detection

FILE STRUCTURE
─────────────────
• Tools\Scan-Compliance.ps1 - Main scanner
• Tools\Apply-Remediation.ps1 - Tag remediation
• Modules/ - Modular components
• Results in Results\* folders

TROUBLESHOOTING
──────────────────
• Authentication issues: Re-run Connect-AzAccount
• API version errors: Script uses multiple fallback methods
• Large environments: Use debug mode for detailed progress
• Policy violations: Review subscription placement of resources

"@ -ForegroundColor White
    
    Write-Host "`nFor detailed documentation, see README.md" -ForegroundColor Blue
    Write-Host "`nPress any key to return to main menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Execute scan function
function Invoke-ComplianceScan {
    param([array]$SubscriptionIds = @(), [switch]$Debug)
    
    Write-Host "`nStarting compliance scan..." -ForegroundColor Yellow
    
    $scanScript = Join-Path $PSScriptRoot "Tools\Scan-Compliance.ps1"
    if (-not (Test-Path $scanScript)) {
        Write-Error "Scan script not found: $scanScript"
        return
    }
    
    if ($SubscriptionIds.Count -gt 0) {
        & $scanScript -SubscriptionIds $SubscriptionIds -Debug:$Debug
    } else {
        & $scanScript -Debug:$Debug
    }
}

# Execute remediation function
function Invoke-TagRemediation {
    param([int]$MinConfidence = 60, [switch]$WhatIf, [switch]$Debug)
    
    Write-Host "`nStarting tag remediation..." -ForegroundColor Yellow
    
    $remediationScript = Join-Path $PSScriptRoot "Tools\Apply-Remediation.ps1"
    if (-not (Test-Path $remediationScript)) {
        Write-Error "Remediation script not found: $remediationScript"
        return
    }
    
    & $remediationScript -MinConfidence $MinConfidence -WhatIf:$WhatIf -Debug:$Debug
}

# View latest results
function Show-LatestResults {
    $latestResults = Get-LatestComplianceResults
    if (-not $latestResults) {
        Write-Host "No scan results found. Please run a compliance scan first." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nLatest Scan Results: $(Split-Path $latestResults -Leaf)" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    
    $csvFiles = Get-ChildItem -Path $latestResults -Filter "*.csv"
    foreach ($file in $csvFiles) {
        $subscriptionName = $file.BaseName -replace '_EnvCompliance_.*$', ''
        $data = Import-Csv $file.FullName
        $issues = $data | Where-Object { $_.Issue }
        
        Write-Host "`n$subscriptionName" -ForegroundColor Yellow
        Write-Host "   Total Resources: $($data.Count)" -ForegroundColor White
        Write-Host "   Issues Found: $($issues.Count)" -ForegroundColor $(if ($issues.Count -eq 0) { 'Green' } else { 'Red' })
        
        if ($issues.Count -gt 0) {
            $highPriority = ($issues | Where-Object { $_.Priority -eq 'HIGH' }).Count
            $mediumPriority = ($issues | Where-Object { $_.Priority -eq 'MEDIUM' }).Count
            Write-Host "   High Priority: $highPriority" -ForegroundColor Red
            Write-Host "   Medium Priority: $mediumPriority" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main execution logic
try {
    # Handle command line automation
    if ($AutoScan) {
        Write-Host "Auto-scan mode activated" -ForegroundColor Yellow
        Invoke-ComplianceScan -Debug:$Debug
        return
    }
    
    if ($AutoRemediate) {
        Write-Host "Auto-remediate mode activated (WhatIf)" -ForegroundColor Yellow
        Invoke-TagRemediation -WhatIf -Debug:$Debug
        return
    }
    
    # Interactive menu loop
    do {
        $choice = Show-MainMenu
        
        switch ($choice.ToUpper()) {
            "1" {
                # Check Azure login first
                $loginInfo = Get-AzureLoginInfo
                if (-not $loginInfo.IsLoggedIn) {
                    Write-Host "`nPlease login to Azure first using Connect-AzAccount" -ForegroundColor Red
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
                Invoke-ComplianceScan -Debug:$Debug
                Write-Host "`nScan completed. Press any key to continue..." -ForegroundColor Green
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                # Check Azure login first
                $loginInfo = Get-AzureLoginInfo
                if (-not $loginInfo.IsLoggedIn) {
                    Write-Host "`nPlease login to Azure first using Connect-AzAccount" -ForegroundColor Red
                    Write-Host "Press any key to continue..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    continue
                }
                Invoke-TagRemediation -WhatIf -Debug:$Debug
                Write-Host "`nRemediation preview completed. Press any key to continue..." -ForegroundColor Green
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Show-LatestResults
            }
            "4" {
                # Advanced options submenu
                do {
                    $advChoice = Show-AdvancedMenu
                    switch ($advChoice.ToUpper()) {
                        "1" {
                            Write-Host "`nEnter subscription IDs (comma-separated, or press Enter for all):"
                            $subInput = Read-Host
                            $subIds = if ($subInput) { $subInput -split ',' | ForEach-Object { $_.Trim() } } else { @() }
                            Invoke-ComplianceScan -SubscriptionIds $subIds -Debug:$Debug
                            Write-Host "`nPress any key to continue..." -ForegroundColor Green
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "2" {
                            $confidence = Read-Host "`nEnter minimum confidence level (default 60)"
                            $confLevel = if ($confidence) { [int]$confidence } else { 60 }
                            Invoke-TagRemediation -MinConfidence $confLevel -WhatIf -Debug:$Debug
                            Write-Host "`nPress any key to continue..." -ForegroundColor Green
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "3" {
                            Invoke-ComplianceScan -Debug
                            Write-Host "`nPress any key to continue..." -ForegroundColor Green
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "4" {
                            Invoke-TagRemediation -WhatIf -Debug
                            Write-Host "`nPress any key to continue..." -ForegroundColor Green
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "5" {
                            Show-LatestResults
                        }
                        "B" { break }
                        default {
                            Write-Host "Invalid selection. Press any key to continue..." -ForegroundColor Red
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                    }
                } while ($advChoice.ToUpper() -ne "B")
            }
            "5" {
                Show-HelpMenu
            }
            "Q" {
                Write-Host "`nThank you for using Azure Environment Tag Compliance!" -ForegroundColor Green
                return
            }
            default {
                Write-Host "`nInvalid selection. Press any key to continue..." -ForegroundColor Red
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($choice.ToUpper() -ne "Q")
    
} catch {
    Write-Error "Menu execution failed: $($_.Exception.Message)"
    if ($Debug) {
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
}
