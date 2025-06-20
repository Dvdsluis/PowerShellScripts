<#
.SYNOPSIS
    Azure authentication management with multi-tenant support
.DESCRIPTION
    Handles Azure authentication, context switching, and suppresses tenant warnings
#>

# Suppress specific Azure warnings
function Set-AzureWarningPreference {
    # Suppress tenant authentication warnings
    $WarningPreference = 'SilentlyContinue'
    
    # Set Azure context to suppress multi-tenant warnings
    $env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"
    $env:AZURE_CORE_OUTPUT = "none"
}

# Test Azure login with enhanced error handling
function Test-AzureLoginEnhanced {
    param(
        [switch]$SuppressWarnings
    )
    
    if ($SuppressWarnings) {
        Set-AzureWarningPreference
    }
    
    try {
        # Suppress warnings during context check
        $oldWarningPreference = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        # Restore warning preference
        $WarningPreference = $oldWarningPreference
        
        if (-not $context) {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

# Get Azure context with warning suppression
function Get-AzureContextSafe {
    param(
        [switch]$SuppressWarnings
    )
    
    try {
        if ($SuppressWarnings) {
            $oldWarningPreference = $WarningPreference
            $WarningPreference = 'SilentlyContinue'
        }
        
        $context = Get-AzContext -ErrorAction SilentlyContinue
        
        if ($SuppressWarnings) {
            $WarningPreference = $oldWarningPreference
        }
        
        return $context
    } catch {
        return $null
    }
}

# Set Azure subscription context with warning suppression
function Set-AzureSubscriptionSafe {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        [switch]$SuppressWarnings
    )
    
    try {
        if ($SuppressWarnings) {
            $oldWarningPreference = $WarningPreference
            $WarningPreference = 'SilentlyContinue'
            
            # Temporarily redirect warning stream
            $oldErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
        }
        
        # Set context and capture any warnings
        $result = Set-AzContext -SubscriptionId $SubscriptionId -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        if ($SuppressWarnings) {
            $WarningPreference = $oldWarningPreference
            $ErrorActionPreference = $oldErrorActionPreference
        }
        
        return $result -ne $null
    } catch {
        if ($SuppressWarnings) {
            $WarningPreference = $oldWarningPreference
            $ErrorActionPreference = $oldErrorActionPreference
        }
        return $false
    }
}

# Get Azure subscriptions with warning suppression
function Get-AzureSubscriptionsSafe {
    param(
        [switch]$SuppressWarnings
    )
    
    try {
        if ($SuppressWarnings) {
            $oldWarningPreference = $WarningPreference
            $WarningPreference = 'SilentlyContinue'
        }
        
        $subscriptions = Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        if ($SuppressWarnings) {
            $WarningPreference = $oldWarningPreference
        }
        
        return $subscriptions
    } catch {
        if ($SuppressWarnings) {
            $WarningPreference = $oldWarningPreference
        }
        return @()
    }
}

# Export functions
Export-ModuleMember -Function Test-AzureLoginEnhanced, Get-AzureContextSafe, Set-AzureSubscriptionSafe, Get-AzureSubscriptionsSafe, Set-AzureWarningPreference
