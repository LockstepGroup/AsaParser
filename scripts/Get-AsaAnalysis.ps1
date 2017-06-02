[CmdletBinding()]
Param (
    [Parameter(Mandatory=$True,Position=0)]
    [string]$ConfigFile
)

Import-Module AsaParser

$Config = Get-Content $ConfigFile


$Objects = Get-AsaObject -Config $Config
$AccessLists = Get-AsaAccessList -Config $Config

$ResolvedAcls = @()
foreach ($Acl in $AccessLists) {
    $ResolvedAcls += Resolve-AsaAccessList $Acl $Objects
}

$ObjectNats = $Objects | Where-Object {$_.NatType}
foreach ($o in $ObjectNats) {
    $o.ResolvedNatSourceAddress = Resolve-AsaObject $o.NatSourceAddress $Objects
}

$ReturnObject = "" | Select Objects,Accesslists,ResolvedAcls,ObjectNats
$ReturnObject.Objects = $Objects
$ReturnObject.Accesslists = $AccessLists
$ReturnObject.ResolvedAcls = $ResolvedAcls
$ReturnObject.ObjectNats = $ObjectNats


return $ReturnObject