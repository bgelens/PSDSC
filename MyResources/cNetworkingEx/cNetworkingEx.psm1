enum LMHOSTSetting {
    Enabled;
    Disabled;
}

[DscResource()]
class cLMHOSTLookup {
    [DscProperty(Key)]
    [String]$Name

    [DscProperty(Mandatory)]
    [LMHOSTSetting]$LMHOSTLookup

    [DscProperty(NotConfigurable)]
    [Bool]$Enabled
    
    [Void]Set() {
        try {
            Invoke-CimMethod -ClassName Win32_NetworkAdapterConfiguration -MethodName EnableWINS -Arguments @{WINSEnableLMHostsLookup = $this.WINSEnableLMHostsLookup($this.LMHOSTLookup)} -ErrorAction Stop
        }
        catch {
            throw "Configuring LMHOST lookup failed with exception: $($_.exception.message)"
        }
    }
    
    [Bool]Test() {
        $CimInstance = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE'
        Write-Verbose -Message "Current state use LMHOST: $($CimInstance[0].WINSEnableLMHostsLookup)"
        if ($CimInstance[0].WINSEnableLMHostsLookup -eq $this.WINSEnableLMHostsLookup($this.LMHOSTLookup)) {
            Write-Verbose -Message "Desired state is the same as current state: $($this.LMHOSTLookup)"
            return $true
        }
        else {
            Write-Verbose -Message "Desired state is not the same as current state: $($this.LMHOSTLookup)"
            return $false
        } 
    }

    [cLMHOSTLookup]Get() {
        return @{
            Name = $this.Name
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