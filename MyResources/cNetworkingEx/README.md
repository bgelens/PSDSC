cNetworkingEx
=============
cNetworkingEX is a DSC resource module hobby project of mine.

The xNetworking module provided by Microsoft contains resources to configure network related settings but it does not encompass everything yet.
With the cNetworkingEx DSC module I want to extend the configuration options available with additional resources to configure more of the networking stack.

Resources
=========
* cLMHOSTLookup
* cNETBIOS
* tbd

cLMHOSTLookup
=============
cLMHOSTLookup enables or disables LMHOST based name resolution.
##Syntax
```
cLMHOSTLookup [String]
{
    LMHOSTLookup = [string]{ Disabled | Enabled }
    Name = [string]
    [DependsOn = [string[]]]
    [PsDscRunAsCredential = [PSCredential]]
}
```
The Name property is a bogus property and is not used anywhere in the configuration.
It is simply there to facilitate the Key property requirement.

The LMHOSTLookup property can either be 'Disabled' or 'Enabled'.
It defines if LMHOST based lookup should be disabled or enabled.
##Configuration
```
configuration LMHOST {
    Import-DscResource -ModuleName cNetworkingEx
    cLMHOSTLookup Disable {
        Name = 'Disable LMHOST Lookup'
        LMHOSTLookup = 'Disabled'
    }
}
```

cNETBIOS
========
cNETBIOS Configures the NETBIOS over TCP/IP settings of a network adapter.
##Synax
```
cNETBIOS [String]
{
    InterfaceName = [string]
    NETBIOSSetting = [string]{ DHCPDefined | Disable | Enable }
    [DependsOn = [string[]]]
    [PsDscRunAsCredential = [PSCredential]]
}
```
The IntefaceName property must be de the Interface Alias name (e.g. Ethernet)

The NETBIOSSetting property defines the desired configuration of the adapter specified.
##Configuration
```
configuration NETBIOS {
    Import-DscResource -ModuleName cNetworkingEx
    cNETBIOS Disable {
        InterfaceName = 'Ethernet'
        NETBIOSSetting = 'Disable'
    }
}
```