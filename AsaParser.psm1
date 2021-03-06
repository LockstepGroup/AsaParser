###############################################################################
## Start Powershell Cmdlets
###############################################################################

###############################################################################
# Get-AsaAccessList

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
                    \ ((?<prottype>object-group)\ )?(?<protocol>[^\ ]+?)
                    
                    # source
                    \ ((?<srctype>host|object-group|object)\ )?(?<source>[^\ ]+)
                    
                    # destination
                    \ ((?<dsttype>host|object-group|object)\ )?(?<destination>[^\ ]+)
                    
                    # service
                    (
                        \ (?<svctype>object-group|eq)\ (?<service>[^\ ]+)|
                        \ (?<svctype>range)\ (?<service>\w+\ \w+)|
                        \ (?<service>echo)
                    )?
                    
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
            $NewObject.SourceType = $Match.Groups['srctype'].Value
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

###############################################################################
# Get-AsaAddress

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

###############################################################################
# Get-AsaCryptoMap

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
            $Name   = $Match.Groups['name'].Value
            $Lookup = $ReturnObject | ? { $_.Name -eq $Name}
            if ($Lookup) {
                $NewObject = $Lookup
            } else {
                $NewObject       = New-Object AsaParser.CryptoMap
                $NewObject.Name  = $Name
                $ReturnObject   += $NewObject
            }
            
            $NewSubObject           = New-Object AsaParser.CryptoMapEntry
            $NewSubObject.Sequence  = $Match.Groups['num'].Value
            $NewSubObject.Acl       = $Match.Groups['acl'].Value
            $NewObject.Entries     += $NewSubObject
            
            Write-Verbose "$VerbosePrefix found map $($NewObject.Name)"
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

###############################################################################
# Get-AsaGroupPolicy

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

        # attribute start
        $Regex = [regex] "group-policy\ (?<name>.+?)\ attributes"
		$Match = HelperEvalRegex $Regex $line -ReturnGroupNum 1
        if ($Match) {
            $KeepGoing = $true
            $NewObject = $ReturnObject | ? { $_.Name -eq $Match }
            continue
        }

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

###############################################################################
# Get-AsaObject

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

###############################################################################
# Get-AsaTunnelGroup

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

###############################################################################
# Get-AsaUsername

function Get-AsaUsername {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets named addresses from saved ASA config file.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$Config
	)
	
	$VerbosePrefix = "Get-AsaUsername:"
	
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

		$Regex = [regex] "username\ (?<name>.+?)\ password\ .+?\ encrypted(\ privilege\ (?<priv>\d+))?"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
            $NewObject      = "" | Select Name,Privilege,ServiceType
            $NewObject.Name = $Match.Groups['name'].Value
            $NewObject.Privilege = $Match.Groups['priv'].Value

            $ReturnObject    += $NewObject
            
            Write-Verbose "$VerbosePrefix found user $($NewObject.Name)"
            $KeepGoing = $true
			continue
		}

        # attribute start
        $Regex = [regex] "username\ (?<name>.+?)\ attributes"
		$Match = HelperEvalRegex $Regex $line -ReturnGroupNum 1
        if ($Match) {
            $KeepGoing = $true
            $NewObject = $ReturnObject | ? { $_.Name -eq $Match }
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
            $EvalParams.ObjectProperty = "ServiceType"
            $EvalParams.Regex          = [regex] '^\ +service-type\ (.+)'
            $Eval                      = HelperEvalRegex @EvalParams
        }
	}	
	return $ReturnObject
}

###############################################################################
# Resolve-AsaAccessList

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

###############################################################################
# Resolve-AsaAccessListRule

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
                'range' {
                    $ResolvedField = @(($Rule.Protocol + '/' + ($FieldValue -replace ' ','-')))
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

###############################################################################
# Resolve-AsaObject

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
	
    $IpMaskRx   = [regex] '^(\d+\.){3}\d+\/\d{1,2}$'
    $IpRangeRx  = [regex] '^(\d+\.){3}\d+-(\d+\.){3}\d+$'
    $ServiceRx  = [regex] '^(tcp|udp|ip|icmp)(\-(tcp|udp|ip|icmp))?(\/(\d+(-\d+)?|echo|traceroute|echo-reply|time-exceeded|unreachable))?$'
    $ProtocolRx = [regex] '^(tcp|udp|ip|icmp|esp|ah)$'
    $ExemptRx   = [regex] '^(any)$'
    $IpRx       = [regex] '^(\d+\.){3}\d+$'
    
    $ReturnObject = @()
    
    foreach ($n in $Name) {
        if ($IpMaskRx.Match($n).Success -or 
            $IpRx.Match($n).Success -or 
            $ServiceRx.Match($n).Success -or 
            $ProtocolRx.Match($n).Success -or
            $IpRangeRx.Match($n).Success -or
            $ExemptRx.Match($n).Success) {
            $ReturnObject += $n
            continue
        }
        
        $Lookup = $ObjectArray | ? { $_.Name -ceq $n }
        if (!($Lookup)) {
            $CheckBuiltin = HelperResolveBuiltinService $n
            if ($CheckBuiltin) {
                $Lookup = "" | Select Type,Value
                $Lookup.Type = "service"
                $Lookup.Value = $n
            } else {
                Throw "$VerbosePrefix Cannot find $n"
            }
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

###############################################################################
## Start Helper Functions
###############################################################################

###############################################################################
# HelperCloneRuleToResolve

function HelperCloneRuleToResolve {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='RxString')]
		[object]$Rule
	)
	
	$VerbosePrefix = "HelperCloneRuleToResolve: "
	
    $RuleProperties = @(
        "Acl",
        "Number",
        "Remark",
        "Action",
        "InActive",
        "ProtocolType",
        "Protocol",
        "SourceType",
        "SourceOrig",
        "SourceResolved",
        "DestinationType",
        "DestinationOrig",
        "DestinationResolved",
        "ServiceType",
        "ServiceOrig",
        "ServiceResolved"
    )

    $NewRule = "" | Select $RuleProperties
    
    $NewRule.Acl                 = $Rule.Acl
    $NewRule.Number              = $Rule.Number
    $NewRule.Remark              = $Rule.Remark
    $NewRule.Action              = $Rule.Action
    $NewRule.InActive            = $Rule.InActive
    $NewRule.ProtocolType        = $Rule.ProtocolType
    $NewRule.Protocol            = $Rule.Protocol
    $NewRule.SourceType          = $Rule.SourceType
    if ($Rule.SourceOrig) {
        $NewRule.SourceOrig          = $Rule.SourceOrig
    } else {
        $NewRule.SourceOrig          = $Rule.Source
    }
    $NewRule.SourceResolved      = $Rule.SourceResolved

    $NewRule.DestinationType     = $Rule.DestinationType
    if ($Rule.DestinationOrig) {
        $NewRule.DestinationOrig     = $Rule.DestinationOrig
    } else {
        $NewRule.DestinationOrig     = $Rule.Destination
    }
    $NewRule.DestinationResolved = $Rule.DestinationResolved
    $NewRule.ServiceType         = $Rule.ServiceType

    if ($Rule.ServiceOrig) {
        $NewRule.ServiceOrig         = $Rule.ServiceOrig
    } else {
        $NewRule.ServiceOrig         = $Rule.Service
    }
    $NewRule.ServiceResolved     = $Rule.ServiceResolved

    return $NewRule
}

###############################################################################
# HelperDetectClassful

function HelperDetectClassful {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='RxString')]
		[ValidatePattern("(\d+\.){3}\d+")]
		[String]$IpAddress
	)
	
	$VerbosePrefix = "HelperDetectClassful: "
	
	$Regex = [regex] "(?x)
					  (?<first>\d+)\.
					  (?<second>\d+)\.
					  (?<third>\d+)\.
					  (?<fourth>\d+)"
						  
	$Match = HelperEvalRegex $Regex $IpAddress
	
	$First  = $Match.Groups['first'].Value
	$Second = $Match.Groups['second'].Value
	$Third  = $Match.Groups['third'].Value
	$Fourth = $Match.Groups['fourth'].Value
	
	$Mask = 32
	if ($Fourth -eq "0") {
		$Mask -= 8
		if ($Third -eq "0") {
			$Mask -= 8
			if ($Second -eq "0") {
				$Mask -= 8
			}
		}
	}
	
	return "$IpAddress/$([string]$Mask)"
}

###############################################################################
# HelperEvalRegex

function HelperEvalRegex {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='RxString')]
		[String]$RegexString,
		
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='Rx')]
		[regex]$Regex,
		
		[Parameter(Mandatory=$True,Position=1)]
		[string]$StringToEval,
		
		[Parameter(Mandatory=$False)]
		[string]$ReturnGroupName,
		
		[Parameter(Mandatory=$False)]
		[int]$ReturnGroupNumber,
		
		[Parameter(Mandatory=$False)]
		$VariableToUpdate,
		
		[Parameter(Mandatory=$False)]
		[string]$ObjectProperty,
		
		[Parameter(Mandatory=$False)]
		[string]$LoopName
	)
	
	$VerbosePrefix = "HelperEvalRegex: "
	
	if ($RegexString) {
		$Regex = [Regex] $RegexString
	}
	
	if ($ReturnGroupName) { $ReturnGroup = $ReturnGroupName }
	if ($ReturnGroupNumber) { $ReturnGroup = $ReturnGroupNumber }
	
	$Match = $Regex.Match($StringToEval)
	if ($Match.Success) {
		#Write-Verbose "$VerbosePrefix Matched: $($Match.Value)"
		if ($ReturnGroup) {
			#Write-Verbose "$VerbosePrefix ReturnGroup"
			switch ($ReturnGroup.Gettype().Name) {
				"Int32" {
					$ReturnValue = $Match.Groups[$ReturnGroup].Value.Trim()
				}
				"String" {
					$ReturnValue = $Match.Groups["$ReturnGroup"].Value.Trim()
				}
				default { Throw "ReturnGroup type invalid" }
			}
			if ($VariableToUpdate) {
				if ($VariableToUpdate.Value.$ObjectProperty) {
					#Property already set on Variable
					continue $LoopName
				} else {
					$VariableToUpdate.Value.$ObjectProperty = $ReturnValue
					Write-Verbose "$ObjectProperty`: $ReturnValue"
				}
				continue $LoopName
			} else {
				return $ReturnValue
			}
		} else {
			return $Match
		}
	} else {
		if ($ObjectToUpdate) {
			return
			# No Match
		} else {
			return $false
		}
	}
}

###############################################################################
# HelperResolveBuiltinService

function HelperResolveBuiltinService {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[String]$Service
	)
    
    $VerbosePrefix = "HelperResolveBuiltinService:"
	
    $Services = @{
        "aol" = "5190"
        "bgp" = "179"
        "biff" = "512"
        "bootpc" = "68"
        "bootps" = "67"
        "chargen" = "19"
        "citrix-ica" = "1494"
        "cmd" = "514"
        "ctiqbe" = "2748"
        "daytime" = "13"
        "discard" = "9"
        "domain" = "53"
        "dnsix" = "195"
        "echo" = "7"
        "exec" = "512"
        "finger" = "79"
        "ftp" = "21"
        "ftp-data" = "20"
        "gopher" = "70"
        "https" = "443"
        "h323" = "1720"
        "hostname" = "101"
        "ident" = "113"
        "imap4" = "143"
        "irc" = "194"
        "isakmp" = "500"
        "kerberos" = "750"
        "klogin" = "543"
        "kshell" = "544"
        "ldap" = "389"
        "ldaps" = "636"
        "lpd" = "515"
        "login" = "513"
        "lotusnotes" = "1352"
        "mobile-ip" = "434"
        "nameserver" = "42"
        "netbios-ns" = "137"
        "netbios-dgm" = "138"
        "netbios-ssn" = "139"
        "nntp" = "119"
        "ntp" = "123"
        "pcanywhere-status" = "5632"
        "pcanywhere-data" = "5631"
        "pim-auto-rp" = "496"
        "pop2" = "109"
        "pop3" = "110"
        "pptp" = "1723"
        "radius" = "1645"
        "radius-acct" = "1646"
        "rip" = "520"
        "secureid-udp" = "5510"
        "sip" = "5060"
        "smtp" = "25"
        "snmp" = "161"
        "snmptrap" = "162"
        "sqlnet" = "1521"
        "ssh" = "22"
        "sunrpc" = "111"
        "syslog" = "514"
        "tacacs" = "49"
        "talk" = "517"
        "telnet" = "23"
        "tftp" = "69"
        "time" = "37"
        "uucp" = "540"
        "who" = "513"
        "whois" = "43"
        "www" = "80"
        "xdmcp" = "177"
    }

    if ($Service -match '^\d+$') {
        return $Service
    } else {
        if ($Services.$Service) {
            return $Services.$Service
        } else {
            Throw "$VerbosePrefix $Service not found"
        }
    }
}

###############################################################################
# HelperTestVerbose

function HelperTestVerbose {
[CmdletBinding()]
param()
    [System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference
}

###############################################################################
## Export Cmdlets
###############################################################################

Export-ModuleMember *-*
