enum Ensure
{
    Present
    Absent
}

[DscResource()]
class cLMHOSTLookup
{
    #LMHOST lookup is enable / disabled system wide for all adapters.
    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$WINSEnableLMHostsLookup


    [Void]Set()
    {
        Invoke-CimMethod -ClassName Win32_NetworkAdapterConfiguration -MethodName EnableWINS -Arguments @{DNSEnabledForWINSResolution = $false; WINSEnableLMHostsLookup = $false}
    }
    
    [Bool]Test()
    {
        $CimInstance = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE'
        if ($CimInstance.DNSEnabledForWINSResolution -eq $this.DNSEnabledForWINSResolution -and $CimInstance.WINSEnableLMHostsLookup -eq $this.WINSEnableLMHostsLookup) {
            return $true
        }
        else {
            return $false
        }
        
    }

    [cLMHOSTLookup]Get()
    {
        return @{}
    }
}


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