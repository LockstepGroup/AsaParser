function Resolve-AsaAccessList {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [AsaParser.AccessList]$AccessList,
        
        [Parameter(Mandatory=$True,Position=1)]
        [array]$ObjectArray
	)
	
	$VerbosePrefix = "Resolve-AsaAccessList:"
    
    $ReturnObject = @()
    
    foreach ($Rule in $AccessList.Rules) {
        $TempRule             = "" | Select Acl,Number,Action,Inactive,
                                            Source,SourceReal,
                                            Destination,DestinationReal,
                                            Service,ServiceReal
        $TempRule.Acl         = $AccessList.Name
        $TempRule.Number      = $Rule.Number
        $TempRule.Action      = $Rule.Action
        $TempRule.InActive    = $Rule.InActive
        $TempRule.Source      = $Rule.Source
        $TempRule.Destination = $Rule.Destination
        $TempRule.Service     = $Rule.Service
        
        $NewRules = @()
        
        Write-Verbose "$VerbosePrefix Sources, $($Rule.Number): $($Rule.Source)"
        if ($Rule.Source) {
            $Sources = Resolve-AsaObject $Rule.Source $ObjectArray
            foreach ($Source in $Sources) {
                $NewRule = $TempRule.psobject.copy()
                $NewRule.SourceReal = $Source
                $NewRules += $NewRule
            }
        } else {
            $NewRule = $TempRule.psobject.copy()
            $NewRule.SourceReal = "any"
            $NewRules += $NewRule
        }
        
        
        $NewDRules = @()
        foreach ($DRule in $NewRules) {
            Write-Verbose "$VerbosePrefix Destination, $($Rule.Number): $($DRule.Destination)"
            
            if ($DRule.Destination) {
                $Destinations = Resolve-AsaObject $DRule.Destination $ObjectArray
                foreach ($Destination in $Destinations) {
                    $NewRule = $DRule.psobject.copy()
                    $NewRule.DestinationReal = $Destination
                    $NewDRules += $NewRule
                }
            } else {
                $NewRule = $TempRule.psobject.copy()
                $NewRule.DestinationReal = "any"
                $NewDRules += $NewRule
            }
        }
        
        $NewRules = $NewDRules
        $NewSRules = @()
        
        foreach ($SvcRule in $NewRules) {
            Write-Verbose "$VerbosePrefix Services, $($Rule.Number): $($SvcRule.Service)"
            
            if ($Rule.Protocol -eq "icmp") {
                $Services = "icmp/" + $SvcRule.Service
            } else {
                if ($SvcRule.Service) {
                    $Services = Resolve-AsaObject $SvcRule.Service $ObjectArray
                } else {
                    $Services = Resolve-AsaObject $Rule.Protocol $ObjectArray
                }
            }
            
            foreach ($Service in $Services) {
                $NewRule = $SvcRule.psobject.copy()
                $NewRule.ServiceReal = $Service
                $NewSRules += $NewRule
            }
        }
        
        $NewRules = $NewSRules
        
        $ReturnObject += $NewRules
    }

    return $ReturnObject
}