function Get-AsaAddress {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaAddress:"
	
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
		
		$Regex = [regex] "name\ (?<ip>$IpRx)\ (?<name>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $NewObject      = New-Object AsaParser.Object
            $NewObject.Name = $Match.Groups['name'].Value
            $NewObject.Type = "address"
            
            $Address     = $Match.Groups['ip'].Value
            $AddressRx   = $IpRx.Match($Address)
            $SecondOctet = $Match.Groups[2].Value
            $ThirdOctet  = $Match.Groups[3].Value
            $FourthOctet = $Match.Groups[4].Value
            
            $Mask = 32
            
            if ($FourthOctet -eq "0") {
                $Mask -= 8
                if ($ThirdOctet -eq "0") {
                    $Mask -= 8
                    if ($SecondOctet -eq "0") {
                        $Mask -= 8
                    }
                }
            }
            
            $NewObject.Value  = $Address + '/' + $Mask
            $ReturnObject    += $NewObject
            
            Write-Verbose "$VerbosePrefix found address $($NewObject.Name)"
			continue
		}
	}	
	return $ReturnObject
}