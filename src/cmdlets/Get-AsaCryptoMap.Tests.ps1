$TestString = @"
crypto map outside_map 1 match address outside_1_cryptomap
crypto map outside_map 1 set pfs 
crypto map outside_map 1 set peer 1.1.1.1 
crypto map outside_map 1 set ikev1 transform-set ESP-DES-SHA
crypto map outside_map 2 match address outside_2_cryptomap
crypto map outside_map 2 set pfs 
crypto map outside_map 2 set peer 2.2.2.2
crypto map outside_map 2 set ikev1 transform-set ESP-3DES-SHA
"@
$TestString = $TestString -split '[\r\n]'

Describe "Get-AsaGroupPolicy" {
    It "returns 2 objects of the correct type" {
        $CryptoMaps = Get-AsaCryptoMap $TestString
        $CryptoMaps.Count | Should Be 2
        $CryptoMaps[0].GetType() | Should Be AsaParser.CryptoMap
    }
}
