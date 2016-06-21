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
            
            <#
            $SourceType = $Match.Groups['sourcetype'].Value
            $Source     = $Match.Groups['source'].Value
            
            switch ($Type) {
                "standard" {
                    # Source
                    $SourceType = $Match.Groups['sourcetype'].Value
                    $Source     = $Match.Groups['source'].Value
                    switch ($SourceType) {
                        "host" {
                            $FullSource = $Source
                            break
                        }
                        default {
                            $Mask = ConvertTo-MaskLength $Source
                            Write-Verbose "$VerbosePrefix $SourceType $Source"
                            $FullSource = $SourceType + '/' + $Mask
                        }
                    }
                    $NewObject.Source = $FullSource
                    break
                }
                "extended" {
                    $NewObject.Protocol = $Match.Groups['protocol'].Value
                    
                    $NewObject.Source = $Match.Groups['source'].Value
                    if ($Match.Groups['srctype'].Value -eq "host") {
                        $NewObject.Source += '/32'
                    }
                    
                    $NewObject.Destination = $Match.Groups['destination'].Value
                    if ($Match.Groups['dsttype'].Value -eq "host") {
                        $NewObject.Destination += '/32'
                    }
                    
                    $NewObject.Service = $Match.Groups['service'].Value
                    
                    if ($Match.Groups['inactive'].Value) {
                        $NewObject.InActive = $true
                    }
                }
            }#>
            
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
            
            $NewObject      = New-Object AsaParser.Object
            $NewObject.Name = $Match.Groups['name'].Value
            $NewObject.Type = $Match.Groups['type'].Value
            
            if ($Match.Groups['group'].Success) {
                $NewObject.IsGroup = $true
            }
            
            $ReturnObject    += $NewObject
            
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
# Resolve-AsaAclRule

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
    
    foreach ($Rule in $AccessList.Rules) {
        $TempRule             = "" | Select Acl,Number,Action,Inactive,
                                            Source,SourceReal,
                                            Destination,DestinationReal,
                                            Service,ServiceReal
        $TempRule.Acl         = $AccessList.Name
        $TempRule.Number      = $Rule.Number
        $TempRule.Action      = $Rule.Action
        $TempRule.InActive    = $Rule.InActive
        $TempRule.Source      = $Rule.Source
        $TempRule.Destination = $Rule.Destination
        $TempRule.Service     = $Rule.Service
        
        $NewRules = @()
        
        Write-Verbose "$VerbosePrefix Sources, $($Rule.Number): $($Rule.Source)"
        if ($Rule.Source) {
            $Sources = Resolve-AsaObject $Rule.Source $ObjectArray
            foreach ($Source in $Sources) {
                $NewRule = $TempRule.psobject.copy()
                $NewRule.SourceReal = $Source
                $NewRules += $NewRule
            }
        } else {
            $NewRule = $TempRule.psobject.copy()
            $NewRule.SourceReal = "any"
            $NewRules += $NewRule
        }
        
        
        $NewDRules = @()
        foreach ($DRule in $NewRules) {
            Write-Verbose "$VerbosePrefix Destination, $($Rule.Number): $($DRule.Destination)"
            
            if ($DRule.Destination) {
                $Destinations = Resolve-AsaObject $DRule.Destination $ObjectArray
                foreach ($Destination in $Destinations) {
                    $NewRule = $DRule.psobject.copy()
                    $NewRule.DestinationReal = $Destination
                    $NewDRules += $NewRule
                }
            } else {
                $NewRule = $TempRule.psobject.copy()
                $NewRule.DestinationReal = "any"
                $NewDRules += $NewRule
            }
        }
        
        $NewRules = $NewDRules
        $NewSRules = @()
        
        foreach ($SvcRule in $NewRules) {
            Write-Verbose "$VerbosePrefix Services, $($Rule.Number): $($SvcRule.Service)"
            
            if ($Rule.Protocol -eq "icmp") {
                $Services = "icmp/" + $SvcRule.Service
            } else {
                if ($SvcRule.Service) {
                    $Services = Resolve-AsaObject $SvcRule.Service $ObjectArray
                } else {
                    $Services = Resolve-AsaObject $Rule.Protocol $ObjectArray
                }
            }
            
            foreach ($Service in $Services) {
                $NewRule = $SvcRule.psobject.copy()
                $NewRule.ServiceReal = $Service
                $NewSRules += $NewRule
            }
        }
        
        $NewRules = $NewSRules
        
        $ReturnObject += $NewRules
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
	
    $IpMaskRx = [regex] '^(\d+\.){3}\d+\/\d{1,2}$'
    $IpRangeRx = [regex] '^(\d+\.){3}\d+-(\d+\.){3}\d+$'
    $ServiceRx = [regex] '^(tcp|udp|ip|icmp)(\/(\d+(-\d+)?|echo|traceroute|echo-reply|time-exceeded|unreachable))?$'
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

###############################################################################
## Start Helper Functions
###############################################################################

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
