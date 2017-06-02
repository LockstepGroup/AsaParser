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
    
    Write-Verbose "$VerbosePrefix $($AccessList.Name)"

    foreach ($Rule in $AccessList.Rules) {
        $NewRules = Resolve-AsaAccessListRule $Rule     Source      $ObjectArray
        $NewRules = Resolve-AsaAccessListRule $NewRules Destination $ObjectArray
        $NewRules = Resolve-AsaAccessListRule $NewRules Service     $ObjectArray

        foreach ($n in $NewRules) {
            $n.Acl = $AccessList.Name
        }

        $ReturnObject += $NewRules
    }

    return $ReturnObject
}