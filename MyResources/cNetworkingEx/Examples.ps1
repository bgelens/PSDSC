configuration LMHOST {
    Import-DscResource -ModuleName cNetworkingEx
    cLMHOSTLookup Disable {
        Name = 'Disable LMHOST Lookup'
        LMHOSTLookup = 'Disabled'
    }
}

configuration NETBIOS {
    Import-DscResource -ModuleName cNetworkingEx
    cNETBIOS Disable {
        InterfaceName = 'Ethernet'
        NETBIOSSetting = 'Disable'
    }
}