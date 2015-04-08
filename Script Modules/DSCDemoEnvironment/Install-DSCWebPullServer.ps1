function Install-DSCWebPullServer
{
    <#
        .SYNOPSIS
        This function installs the DSC Web Pull Server and configures it to require Client Auth Certificates.
    #>
    #region params
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [PScredential]$CertificateCredentials,
            
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [String]$WebenrollURL,
            
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [String]$DSCPullFQDN
    )
    #endregion params
    
    begin
    {}

    process
    {
        #region checks
        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
        {
            Write-Verbose -Message 'Script can only run elevated'
            break
        }
        #endregion checks
    
        #region request webserver certificate
        try
        {
            $DSCPullCert = Get-Certificate -Url $WebenrollURL `
            -Template webserver `
            -SubjectName "CN=$DSCPullFQDN" `
            -DnsName $DSCPullFQDN `
            -CertStoreLocation Cert:\LocalMachine\My `
            -Credential $CertificateCredentials `
            -ErrorAction Stop
        }
        catch
        {
            Write-Verbose -Message 'Certificate Request did not complete successfully'
            break
        }
        #endregion request webserver certificate
    
        #region install roles and features
        Install-WindowsFeature -Name Dsc-Service,Web-Cert-Auth -IncludeManagementTools
        #endregion install roles and features
    
        #region prepare website directory
        $DestinationPath = (New-Item -Path C:\inetpub\wwwroot\PSDSCPullServer -ItemType directory -Force).FullName
        $BinPath = (New-Item -Path $DestinationPath -Name 'bin' -ItemType directory -Force).FullName
        $SourcePath = "$pshome/modules/psdesiredstateconfiguration/pullserver"
        Copy-Item -Path $SourcePath\Global.asax -Destination $DestinationPath\Global.asax -Force | Out-Null
        Copy-Item -Path $SourcePath\PSDSCPullServer.mof -Destination $DestinationPath\PSDSCPullServer.mof -Force | Out-Null
        Copy-Item -Path $SourcePath\PSDSCPullServer.svc -Destination $DestinationPath\PSDSCPullServer.svc -Force | Out-Null
        Copy-Item -Path $SourcePath\PSDSCPullServer.xml -Destination $DestinationPath\PSDSCPullServer.xml -Force | Out-Null
        Copy-Item -Path $SourcePath\PSDSCPullServer.config -Destination $DestinationPath\web.config -Force | Out-Null
        Copy-Item -Path $SourcePath\Microsoft.Powershell.DesiredStateConfiguration.Service.dll -Destination $BinPath -Force | Out-Null
        #endregion prepare website directory
    
        #region import webadmin ps module
        Import-Module -Name 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1'
        #endregion import webadmin ps module
    
        #region configure IIS Aplication Pool
        $AppPool = New-WebAppPool -Name PSWS -Force
        $AppPool.processModel.identityType = 0 #configure app pool to run as local system
        $AppPool.enable32BitAppOnWin64 = $true
        $AppPool | Set-Item
        #endregion configure IIS Aplication Pool
    
        #region create site
        $WebSite = New-Website -Name PSDSCPullServer `
        -PhysicalPath $DestinationPath `
        -ApplicationPool $AppPool.name `
        -Port 443 `
        -IPAddress * `
        -Ssl `
        -SslFlags 1 `
        -HostHeader $DSCPullFQDN `
        -Force
        New-Item -Path "IIS:\SslBindings\!443!$DSCPullFQDN" -Value $DSCPullCert.Certificate -SSLFlags 1 | Out-Null
        #endregion create site
    
        #region unlock config data
        Set-WebConfiguration -PSPath IIS:\ -Filter //access -Metadata overrideMode -value Allow -Force
        Set-WebConfiguration -PSPath IIS:\ -Filter //anonymousAuthentication -Metadata overrideMode -value Allow -Force
        Set-WebConfiguration -PSPath IIS:\ -Filter //basicAuthentication -Metadata overrideMode -value Allow -Force
        Set-WebConfiguration -PSPath IIS:\ -Filter //windowsAuthentication -Metadata overrideMode -value Allow -Force
        Set-WebConfiguration -PSPath IIS:\ -Filter //iisClientCertificateMappingAuthentication -Metadata overrideMode -value Allow -Force
        #endregion unlock config data
    
        #region setup application settings
        Copy-Item -Path $pshome\Modules\PSDesiredStateConfiguration\PullServer\Devices.mdb -Destination $env:programfiles\WindowsPowerShell\DscService -Force
        $configpath = "$env:programfiles\WindowsPowerShell\DscService\Configuration"
        $modulepath = "$env:programfiles\WindowsPowerShell\DscService\Modules"
        $jet4provider = 'System.Data.OleDb'
        $jet4database = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$env:PROGRAMFILES\WindowsPowerShell\DscService\Devices.mdb;"
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath `
        -Filter 'appSettings' `
        -Name '.' `
        -Value @{
            key   = 'dbprovider'
            value = $jet4provider
        } `
        -Force
        
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath `
        -Filter 'appSettings' `
        -Name '.' `
        -Value @{
            key   = 'dbconnectionstr'
            value = $jet4database
        } `
        -Force
        
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath `
        -Filter 'appSettings' `
        -Name '.' `
        -Value @{
            key   = 'ConfigurationPath'
            value = $configpath
        } `
        -Force
        
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath `
        -Filter 'appSettings' `
        -Name '.' `
        -Value @{
            key   = 'ModulePath'
            value = $modulepath
        } `
        -Force
        #endregion setup application settings
    
        #region require client auth certificates
        Set-WebConfiguration -PSPath $WebSite.PSPath -Filter 'system.webserver/security/access' -Value 'Ssl, SslNegotiateCert, SslRequireCert, Ssl128' -Force
        #endregion require client auth certificates
    
        #region create local user for Cert mapping
        # nice simple password generation one-liner by G.A.F.F Jakobs
        # https://gallery.technet.microsoft.com/scriptcenter/Simple-random-code-b2c9c9c9
        $DSCUserPWD = ([char[]](Get-Random -InputObject $(48..57 + 65..90 + 97..122) -Count 12)) -join '' 
        
        $Computer = [ADSI]'WinNT://.,Computer'
        $DSCUser = $Computer.Create('User', 'DSCUser')
        $DSCUser.SetPassword($DSCUserPWD)
        $DSCUser.SetInfo()
        $DSCUser.Description = 'DSC User for Client Certificate Authentication binding '
        $DSCUser.SetInfo()
        $DSCUser.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
        $DSCUser.SetInfo()
        ([ADSI]'WinNT://./IIS_IUSRS,group').Add('WinNT://DSCUser,user')  
        #endregion create local user for Cert mapping
    
        #region configure certificate mapping
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings' -Name '.' -Value @{
            name        = 'DSC Pull Client'
            description = 'DSC Pull Client'
            userName    = 'DSCUser'
            password    = $DSCUserPWD
        }
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings/add[@name='DSC Pull Client']/rules" -Name '.' -Value @{
            certificateField     = 'Issuer'
            certificateSubField  = 'CN'
            matchCriteria        = $DSCPullCert.Certificate.Issuer.Split(',')[0].trimstart('CN=')
            compareCaseSensitive = 'False'
        }
        Set-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisclientCertificateMappingAuthentication' -Name 'enabled' -Value 'True'
        Set-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisclientCertificateMappingAuthentication' -Name 'manyToOneCertificateMappingsEnabled' -Value 'True'
        Set-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisClientCertificateMappingAuthentication' -Name 'oneToOneCertificateMappingsEnabled' -Value 'False'
        #endregion configure certificate mapping
    
        #region configure deny other client certificates
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings' -name '.' -value @{
            name           = 'Deny'
            description    = 'Deny'
            permissionMode = 'Deny'
        }
        #endregion configure deny other client certificates
    
        #region enable CAPI2 Operational Log
        $logName = 'Microsoft-Windows-CAPI2/Operational'
        $log = New-Object -TypeName System.Diagnostics.Eventing.Reader.EventLogConfiguration -ArgumentList $logName
        $log.IsEnabled=$true
        $log.SaveChanges()
        #endregion enable CAPI2 Operational Log
    
        #region remove default web site
        Stop-Website -Name 'Default Web Site'
        Remove-Website -Name 'Default Web Site'
        #endregion remove default web site
    }

    end
    {}
}