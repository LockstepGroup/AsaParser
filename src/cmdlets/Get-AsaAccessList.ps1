function Get-AsaAccessList {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaAccessList:"
	
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
	$n = 1
    
	$TotalLines = $Config.Count
	$i          = 0 
	$StopWatch  = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down
	
	$ReturnObject = @()
	
	:fileloop foreach ($line in $Config) {
		$i++
		
		# Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever
		
		if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
			$PercentComplete = [math]::truncate($i / $TotalLines * 100)
	        Write-Progress -Activity "Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
	        $StopWatch.Reset()
			$StopWatch.Start()
		}
		
		if ($line -eq "") { continue }
		
		###########################################################################################
		# Check for the Section
		
		
        $Regex = [regex] "(?x)
            access-list\ 
            (?<aclname>[^\ ]+?)\ 
            (
                remark\ 
                (?<remark>.+)
            |
                (
                    (?<type>extended)\ 
                    (?<action>[^\ ]+?)
                    
                    # protocol
                    \ (?<prottype>object-group\ )?(?<protocol>[^\ ]+?)
                    
                    # source
                    \ ((?<srctype>host|object-group|object)\ )?(?<source>[^\ ]+)
                    
                    # destination
                    \ ((?<dsttype>host|object-group|object)\ )?(?<destination>[^\ ]+)
                    
                    # service
                    (\ ((?<svctype>object-group|eq)\ )?(?<service>[^\ ]+))?
                    
                    # flags
                    (?<inactive>\ inactive)?
                |
                    (?<type>standard)\ 
                    (?<action>[^\ ]+?)\ 
                    (?<sourcetype>[^\ ]+?)\ 
                    (?<source>[^\ ]+)
                )
            )
        "
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            if ($Match.Groups['remark'].Success) {
                $Remark = $Match.Groups['remark'].Value
                $NewObject.Remark = $Remark
                Write-Verbose "$VerbosePrefix $Remark"
                continue
            } else {
                $NewObject = New-Object AsaParser.AccessListRule
            }
            
            $AclName = $Match.Groups['aclname'].Value
            $Type    = $Match.Groups['type'].Value
            
            
            $CheckForAcl = $ReturnObject | ? { $_.Name -eq $AclName }
            if ($CheckForAcl) {
                $NewAcl = $CheckForAcl
                $n++
            } else {
                $NewAcl = New-Object AsaParser.AccessList
                $NewAcl.Type = $Type
                $NewAcl.Name = $AclName
                $ReturnObject += $NewAcl
                $n = 1
            }
            
            $NewObject.Number = $n
            $NewObject.Action = $Match.Groups['action'].Value
            $NewObject.ProtocolType = $Match.Groups['prottype'].Value
            $NewObject.Protocol = $Match.Groups['protocol'].Value
            $NewObject.SourceType = $Match.Groups['sourcetype'].Value
            $NewObject.Source = $Match.Groups['source'].Value
            $NewObject.DestinationType = $Match.Groups['dsttype'].Value
            $NewObject.Destination = $Match.Groups['destination'].Value
            $NewObject.ServiceType = $Match.Groups['svctype'].Value
            $NewObject.Service = $Match.Groups['service'].Value
            
            if ($Match.Groups['inactive'].Value) {
                $NewObject.InActive = $true
            }
            
            $NewAcl.Rules += $NewObject
			continue
		}
	}	
	return $ReturnObject
}