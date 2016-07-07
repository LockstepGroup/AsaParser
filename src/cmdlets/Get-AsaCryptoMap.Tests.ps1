$TestString = @"
crypto map outside_map 1 match address outside_1_cryptomap
crypto map outside_map 1 set pfs 
crypto map outside_map 1 set peer 1.1.1.1 
crypto map outside_map 1 set ikev1 transform-set ESP-DES-SHA
"@
$TestString = $TestString -split '[\r\n]'

Describe "Get-AsaGroupPolicy" {
    It "returns valid object" {
        $CryptoMaps = Get-AsaCryptoMap $TestString
        $Policy.Name | Should Be "GroupPolicy_anyconnectvpn"
        $Policy.Type | Should Be "internal"
    }
}
