Import-Module $PSScriptRoot\WAPTenantPublicAPI\WAPTenantPublicAPI.psd1 -Force

function Get-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		[parameter(Mandatory)]
		[String] $Name,

		[ValidateSet('Present','Absent')]
		[String] $Ensure,

		[parameter(Mandatory)]
		[String] $URL,

		[parameter(Mandatory)]
		[String] $SubscriptionId,

		[parameter(Mandatory)]
		[PSCredential] $Credential,

		[parameter(Mandatory)]
		[String] $VMRoleName,

		[String] $VMRoleVersion,

		[String] $VMRolePublisher,

		[parameter(Mandatory)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[String] $OSDiskSearch,

		[String] $OSDiskFamilyName,

		[String] $OSDiskRelease,

        [Microsoft.Management.Infrastructure.CimInstance[]]	$VMRoleParameters,

		[parameter(Mandatory)]
		[String] $NetworkReference,

		[parameter(Mandatory)]
		[ValidateSet('ASPNET','ADFS')]
		[String] $TokenSource,

		[parameter(Mandatory)]
		[String] $TokenURL,
        
        #do not define default as functions for ADFS and ASP have different defaults
		[UInt16] $TokenPort,

		[UInt16] $Port = 30006
	)

	$TokenParams = @{
        Credential = $Credential
        URL = $TokenURL
    }
    if ($TokenPort) {
        $TokenParams.Add('Port',$TokenPort)
    }
    
    if ($TokenSource -eq 'ADFS') {
        Write-Verbose "Acquiring ADFS token from $TokenURL with credentials: $($Credential.username)"
        $token =  Get-WAPAdfsToken @TokenParams -Tenant
    }
    else {
        Write-Verbose "Acquiring ASP.Net token from $TokenURL"
        $token = Get-WAPASPNetToken @TokenParams
    }
    
    if ($token -eq $null) {
        throw 'Token could not be acquired'
    }
    Write-Verbose -Message 'Acquired token'

    $Params = @{
        Token = $token
        UserId = $Credential.UserName
        PublicTenantAPIUrl = $url
        Port = $Port
    }

    $Subscription = Get-WAPSubscription @Params -List | Where-Object{$_.SubscriptionID -eq $SubscriptionId}

    if ($Subscription -eq $null) {
        throw "Subscription with id: $SubscriptionId was not found"
    }
    $Subscription | out-string | Write-Verbose

    $Params.Add('Subscription',$Subscription.SubscriptionID)

    if (Get-WAPCloudService @params -Name $Name) {
        $Ensure = 'Present'
    }
    else {
        $Ensure = 'Absent'
    }
    Add-Member -InputObject $PSBoundParameters -MemberType NoteProperty -Name 'Ensure' -Value $Ensure
    $PSBoundParameters.credential = $Credential.UserName
    $PSBoundParameters | Out-String | Write-Verbose
	Write-Output -InputObject $PSBoundParameters
}

function Set-TargetResource {
	[CmdletBinding()]
	param (
		[parameter(Mandatory)]
		[String] $Name,

		[ValidateSet('Present','Absent')]
		[String] $Ensure,

		[parameter(Mandatory)]
		[String] $URL,

		[parameter(Mandatory)]
		[String] $SubscriptionId,

		[parameter(Mandatory)]
		[PSCredential] $Credential,

		[parameter(Mandatory)]
		[String] $VMRoleName,

		[String] $VMRoleVersion,

		[String] $VMRolePublisher,

		[parameter(Mandatory)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[String] $OSDiskSearch,

		[String] $OSDiskFamilyName,

		[String] $OSDiskRelease,

		[parameter(Mandatory)]
		[String] $NetworkReference,

		[Microsoft.Management.Infrastructure.CimInstance[]]	$VMRoleParameters,

		[parameter(Mandatory)]
		[ValidateSet('ASPNET','ADFS')]
		[String] $TokenSource,

		[parameter(Mandatory)]
		[String] $TokenURL,
        
        #do not define default as functions for ADFS and ASP have different defaults
		[UInt16] $TokenPort,

		[UInt16] $Port = 30006
	)

    $TokenParams = @{
        Credential = $Credential
        URL = $TokenURL
    }
    if ($TokenPort) {
        $TokenParams.Add('Port',$TokenPort)
    }
    
    if ($TokenSource -eq 'ADFS') {
        Write-Verbose "Acquiring ADFS token from $TokenURL with credentials: $($Credential.username)"
        $token =  Get-WAPAdfsToken @TokenParams -Tenant
    }
    else {
        Write-Verbose "Acquiring ASP.Net token from $TokenURL"
        $token = Get-WAPASPNetToken @TokenParams
    }
    
    if ($token -eq $null) {
        throw 'Token could not be acquired'
    }
    Write-Verbose -Message 'Acquired token'

    $Params = @{
        Token = $token
        UserId = $Credential.UserName
        PublicTenantAPIUrl = $url
        Port = $Port
    }

    $Subscription = Get-WAPSubscription @Params -List | Where-Object{$_.SubscriptionID -eq $SubscriptionId}

    if ($Subscription -eq $null) {
        throw "Subscription with id: $SubscriptionId was not found"
    }
    $Subscription | out-string | Write-Verbose

    $Params.Add('Subscription',$Subscription.SubscriptionID)

    $GI = Get-WAPGalleryVMRole @Params -Name $VMRoleName

    $GI | Out-String | Write-Verbose

    if ($OSDiskSearch -eq 'LatestApplicable') {
        $OSDisk = Get-WAPVMRoleOSDisk -VMRole $GI @Params | 
            Sort-Object Addedtime -Descending | 
            Select-Object -First 1
    }
    elseif ($OSDiskSearch -eq 'LatestApplicableWithFamilyName') {
        $OSDisk = Get-WAPVMRoleOSDisk -VMRole $GI @Params | 
            Where-Object -FilterScript {$_.FamilyName -eq $OSDiskFamilyName} | 
            Sort-Object Addedtime -Descending | Select-Object -First 1
    }
    elseif ($OSDiskSearch -eq 'Specified') {
        $OSDisk = Get-WAPVMRoleOSDisk -VMRole $GI @Params | 
            Where-Object -FilterScript {$_.FamilyName -eq $OSDiskFamilyName -and $_.Release -eq $OSDiskRelease}
    }

    if ($OSDisk -eq $null) {
        throw 'No valid OS disk was found matching User provided criteria'
    }

    $OSDisk | Out-String | Write-Verbose

    $Net = Get-WAPVMNetwork @Params -Name $NetworkReference

    if ($Net -eq $null) {
        throw 'No valid virtual network was found'
    }

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
		[parameter(Mandatory)]
		[String]	$Name,

		[ValidateSet('Present','Absent')]
		[String] $Ensure,

		[parameter(Mandatory)]
		[String] $URL,

		[parameter(Mandatory)]
		[String] $SubscriptionId,

		[parameter(Mandatory)]
		[PSCredential] $Credential,

		[parameter(Mandatory)]
		[String] $VMRoleName,

		[String] $VMRoleVersion,

		[String] $VMRolePublisher,

		[parameter(Mandatory)]
		[ValidateSet('LatestApplicable','LatestApplicableWithFamilyName','Specified')]
		[String] $OSDiskSearch,

		[String] $OSDiskFamilyName,

		[String] $OSDiskRelease,

		[parameter(Mandatory)]
		[String] $NetworkReference,

		[Microsoft.Management.Infrastructure.CimInstance[]] $VMRoleParameters,

		[parameter(Mandatory)]
		[ValidateSet('ASPNET','ADFS')]
		[String] $TokenSource,

		[parameter(Mandatory)]
		[String] $TokenURL,

		[UInt16] $TokenPort,

		[UInt16] $Port
	)

	if ($TokenSource -eq 'ADFS') {
        Write-Verbose "Acquiring ADFS token from $TokenURL with credentials: $($Credential.username)"
        $token =  Get-WAPAdfsToken -Credential $Credential -URL $TokenURL -Port $TokenPort -Tenant
    }
    else {
        Write-Verbose "Acquiring ASP.Net token from $TokenURL"
        $token = Get-WAPASPNetToken -Credential $Credential -URL $TokenURL -Port $TokenPort
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

    $Subscription = Get-WAPSubscription @Params -List | Where-Object{$_.SubscriptionID -eq $SubscriptionId}

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