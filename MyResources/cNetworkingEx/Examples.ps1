configuration lmhost
{
    Import-DscResource -ModuleName cNetworkingEx
    cLMHOSTLookup disable
    {
        LMHOSTLookup = 'Disabled'

    }
}