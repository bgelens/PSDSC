function Install-PFXWebServer
{
    <#
        .SYNOPSIS
        This function installs the PFX web site
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
        [String]$PFXFQDN
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
            $PFXWebCert = Get-Certificate -Url $WebenrollURL `
            -Template webserver `
            -SubjectName "CN=$PFXFQDN" `
            -DnsName $PFXFQDN `
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
        Install-WindowsFeature -Name Web-Server,Web-Cert-Auth -IncludeManagementTools
        #endregion install roles and features
    
        #region prepare website directory
        $DestinationPath = (New-Item -Path C:\PFXSite -ItemType directory -Force).FullName
        #endregion prepare website directory
    
        #region import webadmin ps module
        Import-Module -Name 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1'
        #endregion import webadmin ps module
    
        #region configure IIS Aplication Pool
        $AppPool = New-WebAppPool -Name PFXWS -Force
        #endregion configure IIS Aplication Pool
    
        #region create site
        $WebSite = New-Website -Name PFX `
        -PhysicalPath $DestinationPath `
        -ApplicationPool $AppPool.name `
        -Port 443 `
        -IPAddress * `
        -Ssl `
        -SslFlags 1 `
        -HostHeader $PFXFQDN `
        -Force
        New-Item -Path "IIS:\SslBindings\!443!$PFXFQDN" -Value $PFXWebCert.Certificate -SSLFlags 1 | Out-Null
        #endregion create site
    
        #region unlock config data
        Set-WebConfiguration -PSPath IIS:\ -Filter //access -Metadata overrideMode -value Allow -Force
        Set-WebConfiguration -PSPath IIS:\ -Filter //iisClientCertificateMappingAuthentication -Metadata overrideMode -value Allow -Force
        #endregion unlock config data
    
        #region disabe anonymous logon
        Set-WebConfigurationProperty -PSPath $WebSite.PSPath  -Filter 'system.webServer/security/authentication/anonymousAuthentication' -Name 'enabled' -Value 'False' -Force
        #endregion disable anonymous logon
    
        #region require client auth certificates
        Set-WebConfiguration -PSPath $WebSite.PSPath -Filter 'system.webserver/security/access' -Value 'Ssl, SslNegotiateCert, SslRequireCert, Ssl128' -Force
        #endregion require client auth certificates
    
        #region create local user for Cert mapping
        # nice simple password generation one-liner by G.A.F.F Jakobs
        # https://gallery.technet.microsoft.com/scriptcenter/Simple-random-code-b2c9c9c9
        $PFXUserPWD = ([char[]](Get-Random -InputObject $(48..57 + 65..90 + 97..122) -Count 12)) -join '' 
        
        $Computer = [ADSI]'WinNT://.,Computer'
        $PFXUser = $Computer.Create('User', 'PFXUser')
        $PFXUser.SetPassword($PFXUserPWD)
        $PFXUser.SetInfo()
        $PFXUser.Description = 'PFX User for Client Certificate Authentication binding '
        $PFXUser.SetInfo()
        $PFXUser.UserFlags = 64 + 65536 # ADS_UF_PASSWD_CANT_CHANGE + ADS_UF_DONT_EXPIRE_PASSWD
        $PFXUser.SetInfo()
        ([ADSI]'WinNT://./IIS_IUSRS,group').Add('WinNT://PFXUser,user')  
        #endregion create local user for Cert mapping
    
        #region configure certificate mapping
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter 'system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings' -Name '.' -Value @{
            name        = 'PFX Web Client'
            description = 'PFX Web Client'
            userName    = 'PFXUser'
            password    = $PFXUserPWD
        }
        Add-WebConfigurationProperty -PSPath $WebSite.PSPath -Filter "system.webServer/security/authentication/iisClientCertificateMappingAuthentication/manyToOneMappings/add[@name='PFX Web Client']/rules" -Name '.' -Value @{
            certificateField     = 'Issuer'
            certificateSubField  = 'CN'
            matchCriteria        = $PFXWebCert.Certificate.Issuer.Split(',')[0].trimstart('CN=')
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
    
        #region set WebFolder ACL
        $Acl = Get-Acl -Path C:\PFXSite
        $Ar = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList ('PFXUser','ReadAndExecute, Synchronize','ContainerInherit, ObjectInherit','None','Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl -Path C:\PFXSite -AclObject $Acl
        #endregion set WebFolder ACL
    }

    end {}
}
