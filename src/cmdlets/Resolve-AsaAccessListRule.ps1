function Resolve-AsaAccessListRule {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [array]$Rules,
        
        [Parameter(Mandatory=$True,Position=1)]
        [ValidateSet("Source","Destination","Service","SourceOrig","DestinationOrig","ServiceOrig")] 
        [string]$Field,
        
        [Parameter(Mandatory=$True,Position=2)]
        [array]$ObjectArray
	)
	
	#$VerbosePrefix = "Resolve-AsaAccessListRule:"
    $VerbosePrefix = "Resolve-AsaAccessListRule:"
    Write-Verbose "$VerbosePrefix RuleCount $($Rules.Count)"
    $ReturnObject = @() 

    foreach ($Rule in $Rules) {
        $VerbosePrefix = "Resolve-AsaAccessListRule:"
        $VerbosePrefix += " " + $Rule.Number + ": "

        if ($Rule."$Field`Orig") {
            $FieldToResolve = "$Field`Orig"
        } else {
            $FieldToResolve = $Field
        }
        
        if ($FieldToResolve -match "Service") {
            Write-Verbose "$VerbosePrefix evaluating service field `'$FieldToResolve`'"
            if ($Rule.$FieldToResolve -eq $null) {
                Write-Verbose "$VerbosePrefix $FieldToResolve is null"
                $FieldToResolve    = "Protocol"
                $ResolvedFieldName = "ServiceResolved"
            } else {
                $ResolvedFieldName = $FieldToResolve + "Resolved" -replace 'Orig',''
            }
        } else {
            $FieldToResolve    = $FieldToResolve
            $ResolvedFieldName = $FieldToResolve + "Resolved" -replace 'Orig',''
        }

        Write-Verbose "$VerbosePrefix FieldToResolve = $FieldToResolve"

        if ($Rule.$FieldToResolve) {
            $TypeField  = $FieldToResolve + "Type" -replace "Orig",""
            $Type       = $Rule.$TypeField
            $FieldValue = $Rule.$FieldToResolve
            Write-Verbose "$VerbosePrefix TypeField `'$TypeField`', Type `'$Type`', FieldValue `'$FieldValue`'"
            switch ($Type) {
                '' {
                    Write-Verbose "$VerbosePrefix Type not defined, returning $FieldValue"
                    $ResolvedField = @($FieldValue)
                }
                { $_ -match 'object' } {
                    $ResolvedField = Resolve-AsaObject $FieldValue $ObjectArray
                }
                'eq' {
                    $ResolvedField = @(($Rule.Protocol + '/' + $FieldValue))
                }
                host {
                    $ResolvedField = @("$FieldValue/32")
                }
                default {
                    Throw "$VerbosePrefix field type not handled `'$Type`'"
                }
            }
            
            foreach ($r in $ResolvedField) {
                $NewRule = HelperCloneRuleToResolve $Rule
                $NewRule.$ResolvedFieldName = $r

                $ReturnObject += $NewRule
            }
        } else {
            $NewRule = HelperCloneRuleToResolve $Rule
            $NewRule.$ResolvedFieldName = "any"
            
            $ReturnObject += $NewRule
        }
    }
    
    return $ReturnObject
}