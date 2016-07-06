function Get-AsaGroupPolicy {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaGroupPolicy:"
	
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

		$Regex = [regex] "group-policy\ (?<name>.+?)\ (?<type>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $NewObject      = "" | Select Name,Type
            $NewObject.Name = $Match.Groups['name'].Value
            $NewObject.Type = $Match.Groups['type'].Value

            $ReturnObject    += $NewObject
            
            Write-Verbose "$VerbosePrefix found policy $($NewObject.Name)"
            $KeepGoing = $true
			continue
		}

        # attribute start
        $Regex = [regex] "group-policy\ (?<name>.+?)\ attributes"
		$Match = HelperEvalRegex $Regex $line -ReturnGroupNum 1
        if ($Match) {
            $KeepGoing = $true
            $NewObject = $ReturnObject | ? { $_.Name -eq $Match }
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
            <#
            # Description
            $EvalParams.ObjectProperty = "ServiceType"
            $EvalParams.Regex          = [regex] '^\ +service-type\ (.+)'
            $Eval                      = HelperEvalRegex @EvalParams
            #>
        }
	}	
	return $ReturnObject
}