$TestString = @"
crypto map outside_map 1 match address outside_1_cryptomap
crypto map outside_map 1 set pfs 
crypto map outside_map 1 set peer 1.1.1.1 
crypto map outside_map 1 set ikev1 transform-set ESP-DES-SHA
crypto map outside_map 2 match address outside_1_cryptomap
crypto map outside_map 2 set pfs 
crypto map outside_map 2 set peer 1.1.1.1 
crypto map outside_map 2 set ikev1 transform-set ESP-DES-SHA
crypto map outside_map2 2 match address outside_2_cryptomap
crypto map outside_map2 2 set pfs 
crypto map outside_map2 2 set peer 2.2.2.2
crypto map outside_map2 2 set ikev1 transform-set ESP-3DES-SHA
"@
$TestString = $TestString -split '[\r\n]'

Describe "Get-AsaCryptoMap" {
    $CryptoMaps = Get-AsaCryptoMap $TestString
    It "return 2 objects of the correct type" {
        $global:test = $CryptoMaps
        $CryptoMaps.Count | Should Be 3
        $CryptoMaps[0].GetType().FullName | Should Be AsaParser.CryptoMap
    }
    It "set CryptoMap Name correctly" {
        $CryptoMaps[0].Name | Should Be 'outside_map'
    }
    It "return correct number of CryptoMaps" {
        $CryptoMaps.Count | Should Be 2
    }
    It "set Sequence correctly" {
        $CryptoMaps[0].Entries[0].Sequence | Should Be 1
    }
    It "set Acl correctly" { 
        $CryptoMaps[0].Entries[0].Acl | Should BeExactly 'outside_1_cryptomap'
    }
    It "set Pfs correctly" {
        $CryptoMaps[0].Entries[0].Pfs | Should Be $true
    }
    It "set Peer correctly" {
        $CryptoMaps[0].Entries[0].Peer | Should Be '1.1.1.1'
    }
    It "set TransformSet correctly" {
        $CryptoMaps[0].Entries[0].TransformSet | Should BeExactly 'ESP-DES-SHA'
    }
}
