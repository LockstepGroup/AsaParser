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