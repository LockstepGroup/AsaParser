function Get-AsaObject {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaObject:"
	
    $IpRx = [regex] "(\d+)\.(\d+)\.(\d+)\.(\d+)"
	
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
		
		$Regex = [regex] "^object(?<group>-group)?\ (?<type>[^\ ]+?)\ (?<name>[^\ ]+)(\ (?<protocol>.+))?"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $KeepGoing = $true
            $Protocol  = $Match.Groups['protocol'].Value
            
            $Lookup = $ReturnObject | Where-Object {$_.Name -ceq $Match.Groups['name'].Value }
            if ($Lookup) {
                $NewObject = $Lookup
            } else {
                $NewObject      = New-Object AsaParser.Object
                $NewObject.Name = $Match.Groups['name'].Value
                $NewObject.Type = $Match.Groups['type'].Value
                
                if ($Match.Groups['group'].Success) {
                    $NewObject.IsGroup = $true
                }
                
                $ReturnObject    += $NewObject
            }

            Write-Verbose "$VerbosePrefix found object $($NewObject.Name)"
			continue
		}
        
        # End object
        $Regex = [regex] "^[^\ ]"
		$Match = HelperEvalRegex $Regex $line
        if ($Match) {
            $KeepGoing = $false
            $Protocol = $null
        }
        
        
        if ($KeepGoing) {
            # Special Properties
            $EvalParams = @{}
            $EvalParams.StringToEval = $line
            
            # subnet
            $EvalParams.Regex = [regex] "^\ subnet\ (?<network>$IpRx)\ (?<mask>$IpRx)"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $Mask = ConvertTo-MaskLength $Eval.Groups['mask'].Value
                $NewObject.Value += $Eval.Groups['network'].Value + '/' + $Mask
            }
            
            # host
            $EvalParams.Regex = [regex] "^\ host\ (?<network>$IpRx)"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $NewObject.Value += $Eval.Groups['network'].Value + '/32'
            }
            
            # network-object
            $EvalParams.Regex = [regex] "^\ network-object\ (?<param1>$IpRx|host|object)\ (?<param2>.+)"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $Param1 = $Eval.Groups['param1'].Value
                switch ($Param1) {
                    "host" {
                        $NewObject.Value += $Eval.Groups['param2'].Value + '/32'
                    }
                    "object" {
                        $NewObject.Value += $Eval.Groups['param2'].Value
                    }
                    { $IpRx.Match($_).Success } {
                        $Mask = ConvertTo-MaskLength $Eval.Groups['param2'].Value
                        $NewObject.Value += $Eval.Groups['param1'].Value + '/' + $Mask
                    }
                }
            }
            
            # port-object
            $EvalParams.Regex = [regex] "^\ port-object\ (?<operator>[^\ ]+?)\ (?<port>[^\ ]+)(\ (?<endport>.+))?"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $Operator = $Eval.Groups['operator'].Value
                $Port = HelperResolveBuiltinService $Eval.Groups['port'].Value
                
                switch ($Operator) {
                    "eq" {
                        $NewObject.Value += $Protocol + '/' + $Port
                    }
                    "range" {
                        $EndPort = HelperResolveBuiltinService $Eval.Groups['endport'].Value
                        $NewObject.Value += $Protocol + '/' + $Port + '-' + $EndPort
                    }
                }
            }
            
            # group-object or protocol-object
            $EvalParams.Regex = [regex] "^\ (group|protocol)-object\ (.+)"				
            $Eval             = HelperEvalRegex @EvalParams -ReturnGroupNum 2
            if ($Eval) {
                $NewObject.Value += $Eval
            }
            
            # icmp-object
            $EvalParams.Regex = [regex] "^\ icmp-object\ (.+)"				
            $Eval             = HelperEvalRegex @EvalParams -ReturnGroupNum 1
            if ($Eval) {
                $NewObject.Value += "icmp/" + $Eval
            }
            
            # range
            $EvalParams.Regex = [regex] "^\ range\ (?<start>$IpRx)\ (?<stop>$IpRx)"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $NewObject.Value += $Eval.Groups['start'].Value + "-" + $Eval.Groups['stop'].Value
            }

            # object nat
            $EvalParams.Regex = [regex] "^\ nat\ \((?<srcint>.+?)\,(?<dstint>.+?)\)\ ((?<type>static)|dynamic\ (?<type>.+?))\ (?<nat>.+)"
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $NewObject.NatSourceInterface      = $Eval.Groups['srcint'].Value
                $NewObject.NatDestinationInterface = $Eval.Groups['dstint'].Value
                $NewObject.NatType                 = $Eval.Groups['type'].Value
                $NewObject.NatSourceAddress        = $Eval.Groups['nat'].Value

            }
            
            # service-object
            $EvalParams.Regex = [regex] "^\ service-object\ (?<protocol>[^\ ]+)(\ (destination\ (?<operator>[^\ ]+)\ (?<port>[^\ ]+)|(?<port>[^\ ]+)))?"				
            $Eval             = HelperEvalRegex @EvalParams
            if ($Eval) {
                $Protocol = $Eval.Groups['protocol'].Value
                $Port     = $Eval.Groups['port'].Value
                
                if ($Eval.Groups['port'].Success) {
                    if ($Protocol -ne "icmp") {
                        $Port = HelperResolveBuiltinService $Port
                    }
                }
                
                if ($Eval.Groups['operator'].Success) {
                    $Operator = $Eval.Groups['operator'].Value
                } else {
                    $Operator = "none"
                }
                
                switch ($Operator) {
                    "eq" {}
                    "none" {}
                    "default" { Throw "$VerbosePrefix service-object operator `"$Operator`" not handled`r`n $line" }
                }
                
                if ($Port) {
                    $FullPort = $Protocol + '/' + $Port
                } else {
                    $FullPort = $Protocol
                }
                $NewObject.Value += $FullPort
            }
            
            ##################################
            # Simple Properties
            $EvalParams.VariableToUpdate = ([REF]$NewObject)
            $EvalParams.ReturnGroupNum   = 1
            $EvalParams.LoopName         = 'fileloop'
            
            # Description
            $EvalParams.ObjectProperty = "Description"
            $EvalParams.Regex          = [regex] '^\ +description\ (.+)'				
            $Eval                      = HelperEvalRegex @EvalParams
        }
	}	
	return $ReturnObject
}