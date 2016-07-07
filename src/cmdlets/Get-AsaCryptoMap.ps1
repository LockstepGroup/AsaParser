function Get-AsaCryptoMap {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaCryptoMap:"
	
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

		$Regex = [regex] "crypto\ map\ (?<name>.+)\ (?<num>\d+)\ match\ address\ (?<acl>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $NewObject       = New-Object AsaParser.CryptoMap
            $NewObject.Name  = $Match.Groups['name'].Value
            $ReturnObject   += $NewObject

            $NewSubObject           = New-Object AsaParser.CryptoMapEntry
            $NewSubObject.Sequence  = $Match.Groups['num'].Value
            $NewSubObject.Acl       = $Match.Groups['acl'].Value
            $NewObject.Entries     += $NewSubObject
            
            Write-Verbose "$VerbosePrefix found map $($NewObject.Name)"
            $KeepGoing = $true
			continue
		}

        if ($KeepGoing) {
            ##################################
            # Special Properties
            $EvalParams = @{}
            $EvalParams.StringToEval = $line

            # Pfs
            $Regex = [regex] "crypto\ map\ .+\ \d+\ set\ pfs"
		    $Match = HelperEvalRegex $Regex $line
            if ($Match) {
                $NewSubObject.Pfs = $true
            }

            # IkeVersion and TransformSet
            $Regex = [regex] "crypto\ map\ .+\ \d+\ set\ ikev(?<ike>\d+)\ transform-set\ (?<transform>.+)"
		    $Match = HelperEvalRegex $Regex $line
            if ($Match) {
                $NewSubObject.IkeVersion   = $Match.Groups['ike'].Value
                $NewSubObject.TransformSet = $Match.Groups['transform'].Value
            }

            ##################################
            # Simple Properties
            $EvalParams.VariableToUpdate = ([REF]$NewSubObject)
            $EvalParams.ReturnGroupNum   = 1
            $EvalParams.LoopName         = 'fileloop'
            
            # Peer
            $EvalParams.ObjectProperty = "Peer"
            $EvalParams.Regex          = [regex] "crypto\ map\ .+\ \d+\ set\ peer\ ($IpRx)"
            $Eval                      = HelperEvalRegex @EvalParams
        }
	}	
	return $ReturnObject
}