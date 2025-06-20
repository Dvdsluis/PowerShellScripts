<#
.SYNOPSIS
    Environment detection logic for Azure resources
.DESCRIPTION
    Provides intelligent environment detection from resource names, locations, and other properties
#>

# Environment detection patterns with confidence levels
$Script:EnvironmentPatterns = @{
    # High confidence (95%) - Delimited patterns
    Delimited = @{
        prod = @('-prod-', '_prod_', '.prod.', '/prod/', '-production-', '_production_', '.production.')
        dev = @('-dev-', '_dev_', '.dev.', '/dev/', '-development-', '_development_', '.development.')
        test = @('-test-', '_test_', '.test.', '/test/', '-testing-', '_testing_', '.testing.')
        acc = @('-acc-', '_acc_', '.acc.', '/acc/', '-accept-', '_accept_', '.accept.', '-acceptance-', '_acceptance_', '.acceptance.')
    }
    # Medium confidence (60%) - Contained patterns
    Contained = @{
        prod = @('prod', 'production', 'live', 'prd')
        dev = @('dev', 'development', 'develop', 'devel') 
        test = @('test', 'testing', 'tst', 'qa', 'quality', 'sandbox', 'sbx')
        acc = @('acc', 'accept', 'acceptance', 'staging', 'stage', 'stg', 'preprod', 'pre-prod')
    }
    # Dutch terms support
    Dutch = @{
        prod = @('productie', 'live')
        dev = @('ontwikkeling', 'dev')
        test = @('test', 'testomgeving')
        acc = @('acceptatie', 'acc', 'staging')
    }
}

# Exclusion patterns to avoid false positives
$Script:ExclusionPatterns = @{
    # Don't classify devops as dev
    DevOpsExclusions = @('devops', 'dev-ops', 'devops-', '-devops')
}

# Detect environment from resource name with confidence scoring
function Get-EnvironmentFromName {
    param(
        [Parameter(Mandatory)]
        [string]$ResourceName,
        [switch]$UseToBeReviewedFallback
    )
    
    $name = $ResourceName.ToLower()
    
    # Check exclusions first
    foreach ($exclusion in $Script:ExclusionPatterns.DevOpsExclusions) {
        if ($name -like "*$exclusion*") {
            return @{
                Environment = "N/A"
                Confidence = 0
                Method = "excluded"
                Reason = "Excluded due to devops pattern: $exclusion"
            }
        }
    }
    
    # Check delimited patterns first (highest confidence)
    foreach ($env in $Script:EnvironmentPatterns.Delimited.Keys) {
        foreach ($pattern in $Script:EnvironmentPatterns.Delimited[$env]) {
            if ($name -like "*$pattern*") {
                return @{
                    Environment = $env
                    Confidence = 95
                    Method = "delimited"
                    Reason = "Environment detected as '$env' from name (delimited) (confidence: 95%)"
                }
            }
        }
    }
    
    # Check contained patterns (medium confidence)
    foreach ($env in $Script:EnvironmentPatterns.Contained.Keys) {
        foreach ($pattern in $Script:EnvironmentPatterns.Contained[$env]) {
            if ($name -like "*$pattern*") {
                return @{
                    Environment = $env
                    Confidence = 60
                    Method = "contained"
                    Reason = "Environment detected as '$env' from name (contained) (confidence: 60%)"
                }
            }
        }
    }
    
    # Check Dutch terms
    foreach ($env in $Script:EnvironmentPatterns.Dutch.Keys) {
        foreach ($pattern in $Script:EnvironmentPatterns.Dutch[$env]) {
            if ($name -like "*$pattern*") {
                return @{
                    Environment = $env
                    Confidence = 80
                    Method = "dutch"
                    Reason = "Environment detected as '$env' from Dutch term (confidence: 80%)"
                }
            }
        }
    }
      # No pattern matched - check for fallback option
    if ($UseToBeReviewedFallback) {
        return @{
            Environment = "ToBeReviewed"
            Confidence = 30
            Method = "fallback"
            Reason = "No environment pattern detected - marked for manual review"
        }
    } else {
        return @{
            Environment = "N/A"
            Confidence = 0
            Method = "none"
            Reason = "No environment pattern detected"
        }
    }
}

# Detect environment from resource location
function Get-EnvironmentFromLocation {
    param(
        [Parameter(Mandatory)]
        [string]$Location
    )
    
    $loc = $Location.ToLower()
    
    # Location-based environment detection (lower confidence)
    if ($loc -like "*prod*" -or $loc -like "*production*") {
        return @{
            Environment = "prod"
            Confidence = 40
            Method = "location"
            Reason = "Environment detected as 'prod' from location (confidence: 40%)"
        }
    }
    
    if ($loc -like "*dev*" -or $loc -like "*development*") {
        return @{
            Environment = "dev"
            Confidence = 40
            Method = "location"
            Reason = "Environment detected as 'dev' from location (confidence: 40%)"
        }
    }
    
    if ($loc -like "*test*" -or $loc -like "*testing*") {
        return @{
            Environment = "test"
            Confidence = 40
            Method = "location"
            Reason = "Environment detected as 'test' from location (confidence: 40%)"
        }
    }
    
    return @{
        Environment = "N/A"
        Confidence = 0
        Method = "location"
        Reason = "No environment detected from location"
    }
}

# Comprehensive environment detection using multiple methods
function Get-EnvironmentDetection {
    param(
        [Parameter(Mandatory)]
        [PSObject]$Resource,
        [switch]$UseToBeReviewedFallback
    )
    
    $detections = @()
    
    # Method 1: Resource name analysis
    $nameDetection = Get-EnvironmentFromName -ResourceName $Resource.Name -UseToBeReviewedFallback:$UseToBeReviewedFallback
    $detections += $nameDetection
    
    # Method 2: Location analysis (if available)
    if ($Resource.Location) {
        $locationDetection = Get-EnvironmentFromLocation -Location $Resource.Location
        $detections += $locationDetection
    }
      # Method 3: Resource group name analysis (if different from resource name)
    if ($Resource.ResourceGroupName -and $Resource.ResourceGroupName -ne $Resource.Name) {
        $rgDetection = Get-EnvironmentFromName -ResourceName $Resource.ResourceGroupName -UseToBeReviewedFallback:$UseToBeReviewedFallback
        if ($rgDetection.Confidence -gt 0) {
            $rgDetection.Method = "resource-group"
            $rgDetection.Reason = $rgDetection.Reason -replace "from name", "from resource group"
            $detections += $rgDetection
        }
    }
    
    # Return the detection with highest confidence
    $bestDetection = $detections | Where-Object { $_.Confidence -gt 0 } | Sort-Object Confidence -Descending | Select-Object -First 1
    
    if ($bestDetection) {
        return $bestDetection
    } else {
        # Fallback if no detection and ToBeReviewed is enabled
        if ($UseToBeReviewedFallback) {
            return @{
                Environment = "ToBeReviewed"
                Confidence = 30
                Method = "fallback"
                Reason = "No environment pattern detected from any source - marked for manual review"
            }
        } else {
            return @{
                Environment = "N/A"
                Confidence = 0
                Method = "none"
                Reason = "No environment pattern detected from any source"
            }
        }
    }
}

# Validate if detected environment is an approved value
function Test-ApprovedEnvironmentTag {
    param([string]$TagValue)
    return $TagValue -in @('prod', 'dev', 'acc', 'test')
}

# Export functions
Export-ModuleMember -Function Get-EnvironmentFromName, Get-EnvironmentFromLocation, Get-EnvironmentDetection, Test-ApprovedEnvironmentTag
