Import-Module $PSScriptRoot\WAPTenantPublicAPI\WAPTenantPublicAPI.psd1 -Force

function Get-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.String]
		$URL,

		[parameter(Mandatory = $true)]
		[System.String]
		$SubscriptionId,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential,

		[parameter(Mandatory = $true)]
		[System.String]
		$VMRoleName,

		[parameter(Mandatory = $true)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[System.String]
		$OSDiskSearch,

		[parameter(Mandatory = $true)]
		[System.String]
		$NetworkReference,

		[parameter(Mandatory = $true)]
		[ValidateSet('ASPNET','ADFS')]
		[System.String]
		$TokenSource,

		[parameter(Mandatory = $true)]
		[System.String]
		$TokenURL
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	<#
	$returnValue = @{
		Name = [System.String]
		URL = [System.String]
		SubscriptionId = [System.String]
		Credential = [System.Management.Automation.PSCredential]
		VMRoleName = [System.String]
		VMRoleVersion = [System.String]
		VMRolePublisher = [System.String]
		OSDiskSearch = [System.String]
		OSDiskFamilyName = [System.String]
		OSDiskRelease = [System.String]
		NetworkReference = [System.String]
		VMRoleParameters = [Microsoft.Management.Infrastructure.CimInstance[]]
		TokenSource = [System.String]
		TokenURL = [System.String]
	}

	$returnValue
	#>
}

function Set-TargetResource {
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.String]
		$URL,

		[parameter(Mandatory = $true)]
		[System.String]
		$SubscriptionId,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential,

		[parameter(Mandatory = $true)]
		[System.String]
		$VMRoleName,

		[System.String]
		$VMRoleVersion,

		[System.String]
		$VMRolePublisher,

		[parameter(Mandatory = $true)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[System.String]
		$OSDiskSearch,

		[System.String]
		$OSDiskFamilyName,

		[System.String]
		$OSDiskRelease,

		[parameter(Mandatory = $true)]
		[System.String]
		$NetworkReference,

		[Microsoft.Management.Infrastructure.CimInstance[]]
		$VMRoleParameters,

		[parameter(Mandatory = $true)]
		[ValidateSet('ASPNET','ADFS')]
		[System.String]
		$TokenSource,

		[parameter(Mandatory = $true)]
		[System.String]
		$TokenURL
	)
    
    if ($TokenSource -eq 'ADFS') {
        Write-Verbose "Acquiring ADFS token from $TokenURL with credentials: $($Credential.username)"
        $token =  Get-WAPAdfsToken -Credential $Credential -AdfsURL $TokenURL -Tenant
    }
    else {
        Write-Verbose "Acquiring ASP.Net token from $TokenURL"
        $token = Get-WAPASPNetToken -Credential $Credential -authSiteAddress $TokenURL
    }
    Write-Verbose -Message "Acquired token $token"
    if ($token -eq $null) {
        throw 'Token could not be acquired'
    }

    $Params = @{
        Token = $token
        UserId = $Credential.UserName
        PublicTenantAPIUrl = $url
        Port = 443
    }

    $Subscription = Get-WAPSubscription @Params -List | ?{$_.SubscriptionID -eq $SubscriptionId}

    if ($Subscription -eq $null) {
        throw "Subscription with id: $SubscriptionId was not found"
    }
    $Subscription | out-string | Write-Verbose

    $Params.Add('Subscription',$Subscription.SubscriptionID)

    $GI = Get-WAPGalleryVMRole @Params -Name $VMRoleName

    $GI | Out-String | Write-Verbose

    $OSDisk = Get-WAPVMRoleOSDisk -VMRole $GI @Params | Sort-Object Addedtime -Descending | Select-Object -First 1

    $OSDisk | Out-String | Write-Verbose

    $Net = Get-WAPVMNetwork @Params -Name $NetworkReference

    $net | Out-String | Write-Verbose

    $VMProps = New-WAPVMRoleParameterObject -VMRole $GI -OSDisk $OSDisk -VMRoleVMSize Medium -VMNetwork $Net

    foreach ($P in $VMRoleParameters) {
        Add-Member -InputObject $VMProps -MemberType NoteProperty -Name $P.key -Value $P.value -Force
    }
    $VMProps | Out-String | Write-Verbose

    New-WAPVMRoleDeployment -VMRole $GI -ParameterObject $VMProps @Params -CloudServiceName $Name | Out-Null
}

function Test-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param (
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[parameter(Mandatory = $true)]
		[System.String]
		$URL,

		[parameter(Mandatory = $true)]
		[System.String]
		$SubscriptionId,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$Credential,

		[parameter(Mandatory = $true)]
		[System.String]
		$VMRoleName,

		[System.String]
		$VMRoleVersion,

		[System.String]
		$VMRolePublisher,

		[parameter(Mandatory = $true)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[System.String]
		$OSDiskSearch,

		[System.String]
		$OSDiskFamilyName,

		[System.String]
		$OSDiskRelease,

		[parameter(Mandatory = $true)]
		[System.String]
		$NetworkReference,

		[Microsoft.Management.Infrastructure.CimInstance[]]
		$VMRoleParameters,

		[parameter(Mandatory = $true)]
		[ValidateSet('ASPNET','ADFS')]
		[System.String]
		$TokenSource,

		[parameter(Mandatory = $true)]
		[System.String]
		$TokenURL
	)

	if ($TokenSource -eq 'ADFS') {
        Write-Verbose "Acquiring ADFS token from $TokenURL with credentials: $($Credential.username)"
        $token =  Get-WAPAdfsToken -Credential $Credential -AdfsURL $TokenURL -Tenant
    }
    else {
        Write-Verbose "Acquiring ASP.Net token from $TokenURL"
        $token = Get-WAPASPNetToken -Credential $Credential -authSiteAddress $TokenURL
    }
    Write-Verbose -Message "Acquired token $token"
    if ($token -eq $null) {
        throw 'Token could not be acquired'
    }

    $Params = @{
        Token = $token
        UserId = $Credential.UserName
        PublicTenantAPIUrl = $url
        Port = 443
    }

    $Subscription = Get-WAPSubscription @Params -List | ?{$_.SubscriptionID -eq $SubscriptionId}

    if ($Subscription -eq $null) {
        throw "Subscription with id: $SubscriptionId was not found"
    }
    #$Subscription | out-string | Write-Verbose

    $Params.Add('Subscription',$Subscription.SubscriptionID)

    if (Get-WAPCloudService @Params -Name $Name) {
        return $true
    }
    else {
        return $false
    }
}

Export-ModuleMember -Function *-TargetResource