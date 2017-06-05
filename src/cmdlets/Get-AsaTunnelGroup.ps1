function Get-AsaTunnelGroup {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaTunnelGroup:"
	
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
		
		$Regex = [regex] "tunnel-group\ (?<name>[^\ ]+?)\ type\ (?<type>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $NewObject      = "" | Select Name,Type,PresharedKey,AddressPool,Policy
            $NewObject.Name = $Match.Groups['name'].Value
            $NewObject.Type = $Match.Groups['type'].Value

            $ReturnObject    += $NewObject
            
            Write-Verbose "$VerbosePrefix found tunnel $($NewObject.Name)"
            $KeepGoing = $true
			continue
		}

        # attribute start
        $Regex = [regex] "tunnel-group\ (?<name>[^\ ]+?)\ (ipsec|webvpn|general)-attributes"
		$Match = HelperEvalRegex $Regex $line
        if ($Match) {
            $KeepGoing = $true
            continue
        }

        #More prompts and blank lines
        $Regex = [regex] '^<'
        $Match = HelperEvalRegex $Regex $line
        if ($Match) {
            continue
        }
        $Regex = [regex] '^\s+$'
        $Match = HelperEvalRegex $Regex $line
        if ($Match) {
            continue
        }

        # End object
        $Regex = [regex] "^[^\ ]"
		$Match = HelperEvalRegex $Regex $line
        if ($Match) {
            $KeepGoing = $false
            continue
        }

        if ($KeepGoing -and $NewObject) {
            ##################################
            # Special Properties
            $EvalParams = @{}
            $EvalParams.StringToEval = $line

            ##################################
            # Simple Properties
            $EvalParams.VariableToUpdate = ([REF]$NewObject)
            $EvalParams.ReturnGroupNum   = 1
            $EvalParams.LoopName         = 'fileloop'
            
            # Description
            $EvalParams.ObjectProperty = "PresharedKey"
            $EvalParams.Regex          = [regex] '^\ +ikev1\ pre-shared-key\ (.+)'
            $Eval                      = HelperEvalRegex @EvalParams

            # AddressPool
            $EvalParams.ObjectProperty = "AddressPool"
            $EvalParams.Regex          = [regex] '^\ +address-pool\ (.+)'
            $Eval                      = HelperEvalRegex @EvalParams

            # Policy
            $EvalParams.ObjectProperty = "Policy"
            $EvalParams.Regex          = [regex] '^\ +default-group-policy\ (.+)'
            $Eval                      = HelperEvalRegex @EvalParams
        }
	}	
	return $ReturnObject
}