$GroupPolicyString = @"
group-policy GroupPolicy_anyconnectvpn internal
group-policy GroupPolicy_anyconnectvpn attributes
 wins-server none
 dns-server value 1.1.1.1 2.2.2.2
 vpn-tunnel-protocol ikev1 ikev2 l2tp-ipsec ssl-client 
 split-tunnel-policy tunnelspecified
 split-tunnel-network-list value securevpn_splitTunnelAcl_1
 default-domain value example.com
 split-dns value example.com example.info example.biz
 split-tunnel-all-dns enable
 webvpn
  anyconnect profiles value anyconnectvpn_client_profile type user
"@
$GroupPolicyString = $GroupPolicyString -split '[\r\n]'

Describe "Get-AsaGroupPolicy" {
    It "returns valid object" {
        $Policy = Get-AsaGroupPolicy $GroupPolicyString
        $Policy.Name | Should Be "GroupPolicy_anyconnectvpn"
        $Policy.Type | Should Be "internal"
    }
}
