<#
.SYNOPSIS
    Azure resource tag operations for Environment Tag Compliance
.DESCRIPTION
    Handles Azure resource tag reading, writing, and validation
#>

# Apply tags to an Azure resource with multiple fallback methods
function Set-ResourceTags {
    param(
        [Parameter(Mandatory)]
        $Resource,
        [Parameter(Mandatory)]
        [hashtable]$Tags,
        [string]$ResourceName
    )
    
    $methods = @(
        @{ Name = "Set-AzResource with Force"; Action = { $Resource | Set-AzResource -Tag $Tags -Force | Out-Null } },
        @{ Name = "Update-AzTag"; Action = { Update-AzTag -ResourceId $Resource.ResourceId -Tag $Tags -Operation Merge | Out-Null } },
        @{ Name = "Set-AzResource without Force"; Action = { $Resource | Set-AzResource -Tag $Tags | Out-Null } }
    )
    
    foreach ($method in $methods) {
        try {
            & $method.Action
            return $true
        } catch {
            Write-Verbose "Method '$($method.Name)' failed: $($_.Exception.Message)"
            continue
        }
    }
    
    # All methods failed
    throw "All tag update methods failed for resource $ResourceName"
}

# Get current tags from a resource, handling null tags properly
function Get-ResourceCurrentTags {
    param(
        [Parameter(Mandatory)]
        $Resource
    )
    
    $currentTags = if ($Resource.Tags) { $Resource.Tags } else { @{} }
    
    # Create a copy of the hashtable (Clone() doesn't exist in PowerShell 7+)
    $newTags = @{}
    if ($currentTags) {
        foreach ($key in $currentTags.Keys) {
            $newTags[$key] = $currentTags[$key]
        }
    }
    
    return $newTags
}

# Apply environment tag to a resource
function Set-EnvironmentTag {
    param(
        [Parameter(Mandatory)]
        [string]$ResourceName,
        [Parameter(Mandatory)]
        [string]$ResourceType,
        [Parameter(Mandatory)]
        [string]$EnvironmentTag,
        [switch]$WhatIf
    )
    
    try {
        # Get the resource
        $resource = Get-AzResource -Name $ResourceName -ResourceType $ResourceType -ErrorAction Stop
        
        if ($resource) {
            $newTags = Get-ResourceCurrentTags -Resource $resource
            $newTags["Environment"] = $EnvironmentTag
            
            if ($WhatIf) {
                return @{
                    Success = $true
                    Action = "WhatIf"
                    ResourceName = $ResourceName
                    CurrentTag = if ($resource.Tags -and $resource.Tags["Environment"]) { $resource.Tags["Environment"] } else { "[MISSING]" }
                    NewTag = $EnvironmentTag
                }
            } else {
                if (Set-ResourceTags -Resource $resource -Tags $newTags -ResourceName $ResourceName) {
                    return @{
                        Success = $true
                        Action = "Applied"
                        ResourceName = $ResourceName
                        CurrentTag = if ($resource.Tags -and $resource.Tags["Environment"]) { $resource.Tags["Environment"] } else { "[MISSING]" }
                        NewTag = $EnvironmentTag
                    }
                }
            }
        } else {
            throw "Resource not found: $ResourceName"
        }
    } catch {
        return @{
            Success = $false
            Action = "Failed"
            ResourceName = $ResourceName
            Error = $_.Exception.Message
        }
    }
}

# Export functions
Export-ModuleMember -Function Set-ResourceTags, Get-ResourceCurrentTags, Set-EnvironmentTag
