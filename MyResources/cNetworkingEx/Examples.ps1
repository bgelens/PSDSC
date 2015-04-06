configuration LMHOST {
    Import-DscResource -ModuleName cNetworkingEx
    cLMHOSTLookup Disable {
        Name = 'Disable LMHOST Lookup'
        LMHOSTLookup = 'Disabled'
    }
}