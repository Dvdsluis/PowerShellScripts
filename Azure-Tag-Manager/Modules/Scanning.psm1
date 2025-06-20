<#
.SYNOPSIS
    Azure resource scanning and analysis for Environment Tag Compliance
.DESCRIPTION
    Handles Azure resource discovery, analysis, and compliance checking
#>

# Get all resources from specified subscriptions
function Get-AzureResources {
    param(
        [string[]]$SubscriptionIds = @(),
        [switch]$Debug
    )
    
    if ($SubscriptionIds.Count -eq 0) {
        try {
            $allSubs = Get-AzSubscription
            $SubscriptionIds = $allSubs.Id
            Write-Host "Found $($SubscriptionIds.Count) subscriptions to scan" -ForegroundColor Gray
        } catch {
            throw "Failed to get subscriptions. Make sure you're logged in with Connect-AzAccount"
        }
    }
    
    $allResources = @()
    $totalSubs = $SubscriptionIds.Count
    $currentSub = 0
    
    foreach ($subId in $SubscriptionIds) {
        $currentSub++
        try {
            $subscription = Get-AzSubscription -SubscriptionId $subId
            Write-Host "[$currentSub/$totalSubs] Processing subscription: $($subscription.Name)" -ForegroundColor Yellow
            
            Set-AzContext -SubscriptionId $subId | Out-Null
            
            $resources = Get-AzResource
            Write-Host "  Found $($resources.Count) resources" -ForegroundColor Gray
            
            # Add subscription info to each resource
            foreach ($resource in $resources) {
                $resource | Add-Member -NotePropertyName 'SubscriptionName' -NotePropertyValue $subscription.Name -Force
                $resource | Add-Member -NotePropertyName 'SubscriptionId' -NotePropertyValue $subId -Force
            }
            
            $allResources += $resources
            
        } catch {
            Write-Warning "Failed to process subscription $subId`: $($_.Exception.Message)"
            continue
        }
    }
    
    Write-Host "Total resources found: $($allResources.Count)" -ForegroundColor Green
    return $allResources
}

# Analyze a resource for environment tag compliance
function Get-ResourceCompliance {
    param(
        [Parameter(Mandatory)]
        [PSObject]$Resource,
        [Parameter(Mandatory)]
        [string]$SubscriptionName,
        [switch]$UseToBeReviewedFallback
    )
    
    # Import required modules for analysis
    Import-Module (Join-Path $PSScriptRoot "EnvironmentDetection.psm1") -Force
    Import-Module (Join-Path $PSScriptRoot "SubscriptionPolicy.psm1") -Force
    
    # Get current environment tag
    $currentEnvTag = if ($Resource.Tags -and $Resource.Tags["Environment"]) { 
        $Resource.Tags["Environment"] 
    } else { 
        "[MISSING]" 
    }
    
    # Get subscription policy
    $policy = Get-SubscriptionPolicy -SubscriptionName $SubscriptionName
      # Detect environment from resource properties
    $detection = Get-EnvironmentDetection -Resource $Resource -UseToBeReviewedFallback:$UseToBeReviewedFallback
    
    $issue = $null
    $recommendation = $null
    $priority = "LOW"
    $issueType = "No Issue"
    $expectedTag = "N/A"
    
    # Check for missing Environment tag
    if ($currentEnvTag -eq "[MISSING]") {
        if ($detection.Environment -ne "N/A" -and (Test-ApprovedEnvironmentTag -TagValue $detection.Environment)) {
            # We can detect the environment and it's approved
            $expectedTag = $detection.Environment
            $issue = "$($detection.Reason) but no Environment tag exists"
            $recommendation = "Add Environment tag with value: $expectedTag"
            $priority = "MEDIUM"
            $issueType = "Missing Environment Tag"
        } else {
            # Cannot detect environment or detected environment is not approved
            $issue = "Missing Environment Tag"
            $recommendation = "Add Environment tag with appropriate value for this subscription ($($policy.AllowedTags -join ', '))"
            $priority = "MEDIUM"
            $issueType = "Missing Environment Tag"
        }
    }
    # Check for invalid Environment tag values
    elseif (-not (Test-ApprovedEnvironmentTag -TagValue $currentEnvTag)) {
        # Current tag is not approved, try to map it
        $standardized = Get-StandardizedEnvironmentTag -TagValue $currentEnvTag
        if ($standardized -ne $currentEnvTag) {
            $expectedTag = $standardized
            $issue = "Environment tag '$currentEnvTag' is not an approved value. Only prod, dev, acc, test are allowed"
            $recommendation = "Change Environment tag from '$currentEnvTag' to '$standardized'"
            $priority = "HIGH"
            $issueType = "Invalid Environment Tag"
        }
    }
    # Check subscription policy compliance
    elseif (-not (Test-TagAllowed -Tag $currentEnvTag -SubscriptionName $SubscriptionName)) {
        $violation = Get-PolicyViolation -Tag $currentEnvTag -SubscriptionName $SubscriptionName -ResourceName $Resource.Name
        $issue = $violation.Message
        $recommendation = "Move resource to appropriate subscription or change tag to allowed value"
        $priority = "HIGH"
        $issueType = "Policy Violation"
    }
      return [PSCustomObject]@{
        ResourceName = $Resource.Name
        ResourceType = $Resource.ResourceType
        DetectedEnv = if ($detection.Environment -eq "N/A") { "N/A" } else { $detection.Environment.ToUpper() }
        ActualEnvTag = $currentEnvTag
        ExpectedEnvTag = $expectedTag
        Issue = $issue
        Recommendation = $recommendation
        Priority = $priority
        IssueType = $issueType
        SubscriptionName = $SubscriptionName
        ResourceGroupName = $Resource.ResourceGroupName
        Location = $Resource.Location
        Confidence = $detection.Confidence
        DetectionMethod = $detection.Method
    }
}

# Standardize environment tag values
function Get-StandardizedEnvironmentTag {
    param([string]$TagValue)
    
    $standardMap = @{
        # Production variants
        'production' = 'prod'
        'live' = 'prod' 
        'prd' = 'prod'
        'productie' = 'prod'
        
        # Development variants
        'development' = 'dev'
        'develop' = 'dev'
        'devel' = 'dev'
        'ontwikkeling' = 'dev'
        
        # Test variants
        'testing' = 'test'
        'tst' = 'test'
        'qa' = 'test'
        'quality' = 'test'
        'sandbox' = 'test'
        'sbx' = 'test'
        'testomgeving' = 'test'
        
        # Acceptance variants
        'acceptance' = 'acc'
        'accept' = 'acc'
        'staging' = 'acc'
        'stage' = 'acc'
        'stg' = 'acc'
        'preprod' = 'acc'
        'pre-prod' = 'acc'
        'acceptatie' = 'acc'
    }
    
    $lower = $TagValue.ToLower()
    if ($standardMap.ContainsKey($lower)) {
        return $standardMap[$lower]
    }
    
    return $TagValue
}

# Export functions
Export-ModuleMember -Function Get-AzureResources, Get-ResourceCompliance, Get-StandardizedEnvironmentTag
