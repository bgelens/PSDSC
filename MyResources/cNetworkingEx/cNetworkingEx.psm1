[DscResource()]
class cLMHOSTLookup
{
    #LMHOST lookup is enable / disabled system wide for all adapters.
    [DscProperty(Key)]
    [ValidateSet('Enabled','Disabled')]
    [String]$LMHOSTLookup

    [DscProperty(NotConfigurable)]
    [Bool]$Enabled
    
    [Void]Set() {
        Invoke-CimMethod -ClassName Win32_NetworkAdapterConfiguration -MethodName EnableWINS -Arguments @{WINSEnableLMHostsLookup = $this.WINSEnableLMHostsLookup($this.LMHOSTLookup)}
    }
    
    [Bool]Test() {
        $CimInstance = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE'
        if ($CimInstance[0].WINSEnableLMHostsLookup -eq $this.WINSEnableLMHostsLookup($this.LMHOSTLookup)) {
            return $true
        }
        else {
            return $false
        }
        
    }

    [cLMHOSTLookup]Get() {
        return @{
            LMHOSTLookup = $this.LMHOSTLookup
            Enabled = $this.WINSEnableLMHostsLookup($this.LMHOSTLookup)
        }
    }

    [bool]WINSEnableLMHostsLookup([String] $LMHOSTLookup) {
        if ($LMHOSTLookup -eq 'Enabled') {
            return $true
        }
        else {
            return $false
        }
    }
}

<#
[DscResource()]
class cNETBIOS
{
    # netbios is handles per adapter ipv4 stack. can have 3 settings: Default (DHCP defined or Enabled), Enabled and Disabled
    [DscProperty(Key)]
    [String]$InterfaceAlias

    [DscProperty(Mandatory)]
    [Bool]$DNSEnabledForWINSResolution

    [Void]Set() {

    }

    [Bool]Test() {
        return $true
    }

    [cNETBIOS]Get() {
        return @{}
    }
}

#Get-CimInstance win32_networkadapterconfiguration -filter 'IPEnabled=TRUE' | Invoke-CimMethod -MethodName settcpipnetbios -Arguments @{TcpipNetbiosOptions = 2}

#Invoke-CimMethod -ClassName Win32_NetworkAdapterConfiguration -MethodName EnableWINS -Arguments @{DNSEnabledForWINSResolution = $false}

#>