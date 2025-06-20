<#
.SYNOPSIS
    Subscription policy management for Environment Tag Compliance
.DESCRIPTION
    Handles subscription-level policies for environment tag validation
#>

# Get subscription policy for environment tags
function Get-SubscriptionPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionName
    )
    
    # Determine if this is a test subscription
    $isTestSubscription = $SubscriptionName -like "*test*" -or 
                         $SubscriptionName -like "*Test*" -or 
                         $SubscriptionName -like "*TEST*"
      if ($isTestSubscription) {
        return @{
            Type = "Test"
            AllowedTags = @('dev', 'test', 'acc', 'ToBeReviewed')
            Description = "Test subscription: Only dev, test, acc, ToBeReviewed tags allowed"
        }
    } else {
        return @{
            Type = "Production"  
            AllowedTags = @('prod', 'ToBeReviewed')
            Description = "Production subscription: Only prod, ToBeReviewed tags allowed"
        }
    }
}

# Validate if a tag is allowed in a subscription
function Test-TagAllowed {
    param(
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$SubscriptionName
    )
    
    $policy = Get-SubscriptionPolicy -SubscriptionName $SubscriptionName
    return $Tag -in $policy.AllowedTags
}

# Get policy violation details
function Get-PolicyViolation {
    param(
        [Parameter(Mandatory)]
        [string]$Tag,
        [Parameter(Mandatory)]
        [string]$SubscriptionName,
        [Parameter(Mandatory)]
        [string]$ResourceName,
        [string]$Issue = ""
    )
    
    $policy = Get-SubscriptionPolicy -SubscriptionName $SubscriptionName
    
    if ($policy.Type -eq "Test" -and $Tag -eq 'prod') {
        return @{
            Type = "ProdInTest"
            Message = "Resource needs 'prod' tag but is in test subscription '$SubscriptionName'"
            Details = "Only dev, test, acc tags allowed in test subscriptions"
            ResourceName = $ResourceName
            Tag = $Tag
            Issue = $Issue
        }
    } elseif ($policy.Type -eq "Production" -and $Tag -in @('dev', 'test', 'acc')) {
        return @{
            Type = "DevTestInProd"
            Message = "Resource needs '$Tag' tag but is in production subscription '$SubscriptionName'"
            Details = "Only prod tags allowed in production subscriptions"
            ResourceName = $ResourceName
            Tag = $Tag
            Issue = $Issue
        }
    } else {
        return @{
            Type = "Other"
            Message = "Expected tag '$Tag' not allowed in subscription '$SubscriptionName'"
            Details = $policy.Description
            ResourceName = $ResourceName
            Tag = $Tag
            Issue = $Issue
        }
    }
}

# Export functions
Export-ModuleMember -Function Get-SubscriptionPolicy, Test-TagAllowed, Get-PolicyViolation
