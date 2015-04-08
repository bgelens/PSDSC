﻿function Install-DSCPKI
{
    <#
        .SYNOPSIS
        This function installs the PKI environment tailored for the PSDSC Pull Server with VM Role Demo
    #>
    #region params
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [String]$CAName,
            
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [String]$CDPURL,
            
        [Parameter(Mandatory,
        ValueFromPipelineByPropertyName)]
        [String]$WebenrollURL
    )
    #endregion params
    begin
    {}

    process
    {
        #region normalize URL to FQDN
        if ($CDPURL -like 'http://*' -or $CDPURL -like 'https://*')
        {
            $CDPURL = $CDPURL.Split('/')[2]
            
        }
        
        if ($WebenrollURL -like 'http://*' -or $WebenrollURL -like 'https://*')
        {
            $WebenrollURL = $WebenrollURL.Split('/')[2]
            
        }
        #endregion normalize URL to FQDN 
    
        #region checks
        if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
        {
            Write-Verbose -Message 'Script can only run elevated'
            break
        }
        $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent() 
        $WindowsPrincipal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList ($CurrentUser)
        if (!($WindowsPrincipal.IsInRole('Enterprise Admins')))
        {
            Write-Verbose -Message 'Script can only run with Enterprise Administrator privileges'
            break
        }
        #endregion checks
    
        #region install required roles and features
        Install-WindowsFeature -Name ADCS-Cert-Authority,ADCS-Enroll-Web-Pol,ADCS-Enroll-Web-Svc -IncludeManagementTools
        #endregion install required roles and features
    
        #region Install Enterprise Root CA
        try
        {
            Install-AdcsCertificationAuthority -WhatIf
        }
        catch
        {
            Write-Verbose -Message 'A CA is already installed on this server, cleanup server and AD before running this script again'
            break
        }
        if ((certutil.exe -adca |Select-String -Pattern 'cn =').line.Substring(7) -contains $CAName)
        {
            Write-Verbose -Message "An Enterprise CA with the CA Name $CAName already exists"
            break
        }
        
        
        New-Item -Path C:\Windows\capolicy.inf -ItemType file -Force | Out-Null
        @"
[Version]
Signature="`$Windows NT$"

[PolicyStatementExtension]
Policies=InternalUseOnly
[InternalUseOnly]
OID=2.5.29.32.0
Notice="This CA is used for a DSC demo environment"

[Certsrv_Server]
LoadDefaultTemplates=0
AlternateSignatureAlgorithm=1

[Extensions]
2.5.29.15 = AwIBBg==
Critical = 2.5.29.15
"@ | Out-File -FilePath C:\Windows\capolicy.inf -Force
        
        Install-AdcsCertificationAuthority -CACommonName $CAName `
        -CAType EnterpriseRootCA `
        -CADistinguishedNameSuffix 'O=DSCCompany,C=NL' `
        -HashAlgorithmName sha256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 10 `
        -CryptoProviderName 'RSA#Microsoft Software Key Storage Provider' `
        -KeyLength 4096 `
        -Force
        
        certutil.exe -setreg CA\AuditFilter 127
        certutil.exe -setreg CA\ValidityPeriodUnits 4
        certutil.exe -setreg CA\ValidityPeriod 'Years'
        #endregion Install Enterprise Root CA
    
        #region configure CA settings and prepare AIA / CDP
        New-Item -Path c:\CDP -ItemType directory -Force
        Copy-Item -Path C:\Windows\System32\CertSrv\CertEnroll\*.crt -Destination C:\CDP\$CAName.crt -Force
        Get-CAAuthorityInformationAccess | Remove-CAAuthorityInformationAccess -Force
        Get-CACrlDistributionPoint | Remove-CACrlDistributionPoint -Force
        Add-CAAuthorityInformationAccess -Uri http://$CDPURL/$CAName.crt -AddToCertificateAia -Force
        Add-CACrlDistributionPoint -Uri C:\CDP\<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl -PublishToServer -PublishDeltaToServer -Force
        Add-CACrlDistributionPoint -Uri http://$CDPURL/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl -AddToCertificateCdp -AddToFreshestCrl -Force
        #endregion configure CA settings and prepare AIA / CDP
    
        #region create CDP / AIA web site
        Import-Module -Name 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1'
        New-Website -Name CDP -HostHeader $CDPURL -Port 80 -IPAddress * -Force
        Set-ItemProperty -Path 'IIS:\Sites\CDP' -Name physicalpath -Value C:\CDP
        Set-WebConfigurationProperty -PSPath 'IIS:\Sites\CDP' -Filter /system.webServer/directoryBrowse  -Name enabled -Value true
        Set-WebConfigurationProperty -PSPath 'IIS:\Sites\CDP' -Filter /system.webServer/security/requestfiltering  -Name allowDoubleEscaping -Value true
        attrib.exe +h C:\CDP\web.config
        #endregion create CDP / AIA web site
    
        #region restart CA service and publish CRL
        Restart-Service -Name CertSvc
        Start-Sleep -Seconds 5
        certutil.exe -CRL
        #endregion restart CA service and publish CRL
    
        #region add webserver template
        Invoke-Command -ComputerName ($env:LOGONSERVER).Trim('\') -ScriptBlock {
            $DN = (Get-ADDomain).DistinguishedName
            $WebTemplate = "CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$DN"
            DSACLS $WebTemplate /G 'Authenticated Users:CA;Enroll' 
        }
        
        certutil.exe -setcatemplates +WebServer
        #endregion add webserver template
    
        #region request web server certificate
        $cert = Get-Certificate -Template webserver -DnsName $webenrollURL -SubjectName "CN=$webenrollURL" -CertStoreLocation cert:\LocalMachine\My
        #endregion request web server certificate
    
        #region Install enrollment web services
        Install-AdcsEnrollmentPolicyWebService -AuthenticationType UserName -SSLCertThumbprint $cert.Certificate.Thumbprint -Force
        Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/ADPolicyProvider_CEP_UsernamePassword'  -filter "appSettings/add[@key='FriendlyName']" -name 'value' -value 'DSC CA' -Force
        Install-AdcsEnrollmentWebService -AuthenticationType UserName -SSLCertThumbprint $cert.Certificate.Thumbprint -Force
        #endregion Install enrollment web services
    
        #region modify Enrollment Server URL in AD
        Invoke-Command -ComputerName ($env:LOGONSERVER).Trim('\') -ScriptBlock {
            param
            (
                $CAName,
                $webenrollURL
            )
            $DN = (Get-ADDomain).DistinguishedName
            $CAEnrollmentServiceDN = "CN=$CAName,CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,$DN"
            Set-ADObject $CAEnrollmentServiceDN -Replace @{'msPKI-Enrollment-Servers'="1`n4`n0`nhttps://$webenrollURL/$CAName`_CES_UsernamePassword/service.svc/CES`n0"}
        } -ArgumentList $CAName, $webenrollURL     
        #endregion modify Enrollment Server URL in AD
    }

    end
    {}
}