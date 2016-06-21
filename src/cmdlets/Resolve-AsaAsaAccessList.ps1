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
                                            SourceOrig,SourceResolved,
                                            DestinationOrig,DestinationResolved,
                                            ServiceOrig,ServiceResolved
        
        $TempRule.Acl             = $AccessList.Name
        $TempRule.Number          = $Rule.Number
        $TempRule.Action          = $Rule.Action
        $TempRule.InActive        = $Rule.InActive
        $TempRule.SourceOrig      = $Rule.Source
        $TempRule.DestinationOrig = $Rule.Destination
        $TempRule.ServiceOrig     = $Rule.Service
        
        
        
        
        # Combine Protocol and Service to make ServiceResolved
        $ProtocolRules = @()
        if ($Rule.ProtocolType) {
            Write-Verbose "$VerbosePrefix Rule $($Rule.Number) ProtocolType Found"
            switch ($Rule.ProtocolType) {
                'object-group' {
                    $ResolvedProtocols = Resolve-AsaObject $Rule.Protocol $ObjectArray
                    break
                }
                default {
                    Throw "$VerbosePrefix Rule $($Rule.Number) ProtocolType `"$($Rule.ProtocolType)`" not handled"
                }
            }
            
            foreach ($item in $ResolvedProtocols) {
                $NewRule = $TempRule.psobject.copy()
                $NewRule.ServiceResolved = $item
                if ($TempRule.ServiceOrig) {
                    $NewRule.ServiceResolved += '/' + $TempRule.ServiceOrig
                }
                $ProtocolRules += $NewRule
            }
        } else {
            $ProtocolRules += $TempRule.psobject.copy()
        }
        
        # Services
        $ServiceRules = @()
        foreach ($PRule in $ProtocolRules) {
            $CurrentService = $PRule.ServiceOrig
            if ($CurrentService) {
                switch ($Rule.ServiceType) {
                    'object-group' {
                        $ResolvedServices = Resolve-AsaObject $CurrentService $ObjectArray
                        break
                    }
                    'eq' {
                        if ($CurrentService -match '^\d+$') {
                            $ResolvedServices = @(($Rule.Protocol + '/' + $CurrentService)) 
                        } else {
                            $ResolvedServices = @(($Rule.Protocol + '/' + (HelperResolveBuiltinService $CurrentService)))
                        }
                    }
                    default {
                        $ResolvedServices = @(($Rule.Protocol + '/' + $CurrentService))
                    }
                }
                
                foreach ($item in $ResolvedServices) {
                    $NewRule = $PRule.psobject.copy()
                    $NewRule.ServiceResolved = $item
                    $ServiceRules += $NewRule
                }
            } else {
                $NewRule = $PRule.psobject.copy()
                $NewRule.ServiceResolved = 'any'
                $ServiceRules += $NewRule
            }
        }
        
        # Sources
        $SourceRules = @()
        foreach ($SRule in $ServiceRules) {
            $CurrentSource = $SRule.SourceOrig
            switch ($Rule.SourceType) {
                { ($_ -eq 'object-group') -or
                  ($_ -eq 'object')           } {
                    $ResolvedSources = Resolve-AsaObject $CurrentSource $ObjectArray
                }
                'host' {
                    $ResolvedSources = @(($CurrentSource + '/32'))
                }
                default {
                    $ResolvedSources = @($CurrentSource)
                }
            }
            
            foreach ($item in $ResolvedSources) {
                $NewRule = $SRule.psobject.copy()
                $NewRule.SourceResolved = $item
                $SourceRules += $NewRule
            }
        }
        
        # Destination
        $DestinationRules = @()
        foreach ($SrcRule in $SourceRules) {
            $CurrentDestination = $SrcRule.DestinationOrig
            switch ($Rule.DestinationType) {
                { ($_ -eq 'object-group') -or
                  ($_ -eq 'object')           } {
                    $ResolvedDestinations = Resolve-AsaObject $CurrentDestination $ObjectArray
                }
                'host' {
                    $ResolvedDestinations = @(($CurrentDestination + '/32'))
                }
                default {
                    $ResolvedDestinations = @($CurrentDestination)
                }
            }
            
            foreach ($item in $ResolvedDestinations) {
                $NewRule = $SrcRule.psobject.copy()
                $NewRule.DestinationResolved = $item
                $DestinationRules += $NewRule
            }
        }
        
        $NewRules = $DestinationRules
        
        $ReturnObject += $NewRules
    }

    return $ReturnObject
}