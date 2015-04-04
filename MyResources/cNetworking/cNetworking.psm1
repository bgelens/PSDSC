[DscResource()]
class cLMHOST
{
    [DscProperty(Key)]
    [ValidateSet('Present','Absent')]
    [String]$Ensure

    [DscProperty(Mandatory)]
    [Bool]$DNSEnabledForWINSResolution

    [DscProperty(Mandatory)]
    [Bool]$WINSEnableLMHostsLookup

    #networkadapteralias? #key?

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

    [cLMHOST]Get()
    {
        return @{}
    }
}