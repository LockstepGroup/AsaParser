function Resolve-AsaObject {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
        [string]$Name,
        
        [Parameter(Mandatory=$True,Position=1)]
        [array]$ObjectArray
	)
	
	$VerbosePrefix = "Resolve-AsaObject:"
	
    $IpMaskRx = [regex] '^(\d+\.){3}\d+\/\d{1,2}$'
    $IpRangeRx = [regex] '^(\d+\.){3}\d+-(\d+\.){3}\d+$'
    $ServiceRx = [regex] '^(tcp|udp|ip|icmp)(\-(tcp|udp|ip|icmp))?(\/(\d+(-\d+)?|echo|traceroute|echo-reply|time-exceeded|unreachable))?$'
    $ProtocolRx = [regex] '^(tcp|udp|ip|icmp|esp|ah)$'
    $ExemptRx = [regex] '^(any)$'
    
    $ReturnObject = @()
    
    foreach ($n in $Name) {
        if ($IpMaskRx.Match($n).Success -or 
            $ServiceRx.Match($n).Success -or 
            $ProtocolRx.Match($n).Success -or
            $IpRangeRx.Match($n).Success -or
            $ExemptRx.Match($n).Success) {
            $ReturnObject += $n
            continue
        }
        
        $Lookup = $ObjectArray | ? { $_.Name -ceq $n }
        if (!($Lookup)) {
            Throw "$VerbosePrefix Cannot find $n"
        }
        
        switch ($Lookup.Type) {
            "address" {
                foreach ($entry in $Lookup.Value) {
                    $ReturnObject += $entry
                }
                break
            }
            { ( $_ -eq "network" ) -or 
              ( $_ -eq "icmp-type" ) -or 
              ( $_ -eq "protocol" ) } {
                foreach ($entry in $Lookup.Value) {
                    Resolve-AsaObject $entry $ObjectArray
                }
                break
            }
            "service" {
                foreach ($entry in $Lookup.Value) {
                    try {
                        HelperResolveBuiltinService $entry
                    } catch {
                        Resolve-AsaObject $entry $ObjectArray
                    }
                }
            }
            default {
                Throw "$VerbosePrefix Type `"$($Lookup.Type)`" not handled"
            }
        }
    }
    
    return $ReturnObject
}