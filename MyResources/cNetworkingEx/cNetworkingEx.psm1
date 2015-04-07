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


enum NETBIOSSetting {
    DHCPDefined;
    Enable;
    Disable;
}

[DscResource()]
class cNETBIOS
{
    [DscProperty(Key)]
    [String]$InterfaceName

    [DscProperty(Mandatory)]
    [NETBIOSSetting]$NETBIOSSetting

    [DscProperty(NotConfigurable)]
    [String]$ActiveSetting

    [Void]Set() {
        $ErrorActionPreference = 'Stop'
        try {
            $NetAdapterConfig = Get-CimInstance -ClassName Win32_NetworkAdapter | 
                ?{$_.NetConnectionID -eq $this.InterfaceName} |
                    Get-CimAssociatedInstance -ResultClassName Win32_NetworkAdapterConfiguration 
            if ($this.NETBIOSSetting -eq [NETBIOSSetting]::DHCPDefined) {
                #If DHCP is not enabled, settcpipnetbios CIM Method won't take 0.
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($NetAdapterConfig.SettingID)" -Name NetbiosOptions -Value 0
            }
            else {
                $NetAdapterConfig | Invoke-CimMethod -MethodName settcpipnetbios -Arguments @{TcpipNetbiosOptions = [uint32]$($this.SettingToIndex([NETBIOSSetting]::$($this.NETBIOSSetting)))}
            }
        }
        catch {
            throw "Exeption happened: $($_.exception.message)"
        }
    }

    [Bool]Test() {
        $ErrorActionPreference = 'Stop'
        try {
            $NIC = Get-CimInstance -ClassName Win32_NetworkAdapter| ?{$_.NetConnectionID -eq $this.InterfaceName}
            Write-Verbose -Message "Interface $($this.InterfaceName) detected with Index number: $($NIC.InterfaceIndex)"

            $NICConfig = $NIC | Get-CimAssociatedInstance -ResultClassName win32_networkadapterconfiguration
            Write-Verbose -Message "Current Netbios Configuration: $($this.IndexToSetting($NICConfig.TcpipNetbiosOptions))"

            $DesiredSetting = ([NETBIOSSetting]::$($this.NETBIOSSetting)).value__
            Write-Verbose -Message "Desired Netbios Configuration: $($this.NETBIOSSetting)"

            if ($NICConfig.TcpipNetbiosOptions -eq $DesiredSetting) {
                return $true
            }
            else {
                return $false
            }
        }
        catch {
            throw "Exeption happened: $($_.exception.message)"
        }
    }

    [cNETBIOS]Get() {
        return @{
            InterfaceName = $this.InterfaceName
            NETBIOSSetting = $this.NETBIOSSetting
            ActiveSetting = $this.IndexToSetting($this.ActiveSettingIndex())
        }
    }

    [Int]SettingToIndex([String] $Setting) {
        return ([NETBIOSSetting]::$Setting).value__
    }

    [String]IndexToSetting([int] $Index) {
        return [NETBIOSSetting].GetEnumValues()[$Index]
    }

    [Int]ActiveSettingIndex() {
        $NICConfig = Get-CimInstance -ClassName Win32_NetworkAdapter| ?{$_.NetConnectionID -eq $this.InterfaceName} |
            Get-CimAssociatedInstance -ResultClassName win32_networkadapterconfiguration
        return $NICConfig.TcpipNetbiosOptions
    }
}