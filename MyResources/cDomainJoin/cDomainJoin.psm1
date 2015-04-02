enum Ensure
{
   Absent
   Present
}

[DscResource()]
class cDomainJoin
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [String]$Domain

    [DscProperty(Mandatory)]
    [PSCredential]$Credential

    [Void]Set()
    {
        if ($this.Ensure -eq [Ensure]::Present)
        {
            try
            {
                Add-Computer -DomainName $this.Domain -Credential $this.Credential -Force -PassThru -ErrorAction Stop
                $global:DSCMachineStatus = 1
            }
            catch
            {
                throw 'Exception happened joining computer to domain'
            }
            }
        else
        {
            try
            {
                Remove-Computer -UnjoinDomainCredential $this.Credential -WorkgroupName 'Workgroup' -Force -PassThru -ErrorAction Stop
                $global:DSCMachineStatus = 1
            }
            catch
            {
                throw 'Exception happened removing computer from domain'
            }
        }
    }
    
    [Bool]Test()
    {
        if ($this.Ensure -eq [Ensure]::Present)
        {
            Write-Verbose "Checking if the computer is a member of domain: $($this.Domain)"
            if ((Get-CimInstance -ClassName Win32_ComputerSystem).Domain -eq $this.Domain)
            {
                Write-Verbose "Computer is member of the domain: $($this.Domain)"
                return $true
            }
            else
            {
                Write-Verbose "Computer is not a member of the domain: $($this.Domain)"
                return $false
            }
        }
        else
        {
            Write-Verbose -Message "Checking if the computer is a member of the Workgroup"
            if ((Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain)
            {
                Write-Verbose "Computer is member of a domain"
                return $false
            }
            else
            {
                Write-Verbose "Computer is member a Workgroup member"
                return $true
            }
        }
    }

    [cDomainJoin]Get()
    {
        $Environment = Get-CimInstance -ClassName Win32_ComputerSystem
        $Configuration = [hashtable]::new()
        $Configuration.Add('Domain',$this.Domain)
        $Configuration.Add('Credential',$this.Credential)
        if ($this.Domain -eq $Environment.Domain)
        {
            $Configuration.Add('Ensure','Present')
        }
        else
        {
            $Configuration.Add('Ensure','Absent')
        }
        return $Configuration
    }
}