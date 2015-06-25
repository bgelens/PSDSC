Import-Module xDSCResourceDesigner

New-xDscResource -ModuleName cWAPack -Name 'BG_WAPackVMRole' -FriendlyName 'WAPackVMRole' -ClassVersion '0.0.0.1' -Path C:\GIT\PSDSC\MyResources\ -Property @(
    New-xDscResourceProperty -Name Name -Type String -Attribute Key -Description 'Cloud Service and VM Role Name'
    New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValueMap 'Present','Absent' -Values 'Present','Absent'
    New-xDscResourceProperty -Name URL -Type String -Attribute Required -Description 'Tenant Public API or Tenant API URL'
    New-xDscResourceProperty -Name SubscriptionId -Type String -Attribute Required -Description 'Subscription ID'
    New-xDscResourceProperty -Name Credential -Type PSCredential -Attribute Required -Description 'Credentials to acquire token'
    New-xDscResourceProperty -Name VMRoleName -Type String -Attribute Required
    New-xDscResourceProperty -Name VMRoleVersion -Type String -Attribute Write
    New-xDscResourceProperty -Name VMRolePublisher -Type String -Attribute Write
    New-xDscResourceProperty -Name OSDiskSearch -Type String -Attribute Required -ValueMap 'LatestApplicable','LatestApplicableWithFamilyName','Specified' -Values 'LatestApplicable','LatestApplicableWithFamilyName','Specified'
    New-xDscResourceProperty -Name OSDiskFamilyName -Type String -Attribute write
    New-xDscResourceProperty -Name OSDiskRelease -Type String -Attribute Write
    New-xDscResourceProperty -Name NetworkReference -Type String -Attribute Required
    New-xDscResourceProperty -Name VMRoleParameters -Type Hashtable -Attribute Write
    New-xDscResourceProperty -Name TokenSource -Type String -Attribute Required -ValueMap 'ASPNET','ADFS' -Values 'ASPNET','ADFS'
    New-xDscResourceProperty -Name TokenURL -Type String -Attribute Required
    New-xDscResourceProperty -Name TokenPort -Type Uint16 -Attribute Write -Description 'Specify custom port to acquire token. Defaults for ADFS: 443, ASP.Net: 30071'
    New-xDscResourceProperty -Name Port -Type Uint16 -Attribute Write -Description 'Specify API port. Default: 30006'
) -Force

Update-xDscResource -Path C:\GIT\PSDSC\MyResources\cWAPack\DSCResources\BG_WAPackVMRole -Property @(
    New-xDscResourceProperty -Name Name -Type String -Attribute Key -Description 'Cloud Service and VM Role Name'
    New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValueMap 'Present','Absent' -Values 'Present','Absent'
    New-xDscResourceProperty -Name URL -Type String -Attribute Required -Description 'Tenant Public API or Tenant API URL'
    New-xDscResourceProperty -Name SubscriptionId -Type String -Attribute Required -Description 'Subscription ID'
    New-xDscResourceProperty -Name Credential -Type PSCredential -Attribute Required -Description 'Credentials to acquire token'
    New-xDscResourceProperty -Name VMRoleName -Type String -Attribute Required
    New-xDscResourceProperty -Name VMRoleVersion -Type String -Attribute Write
    New-xDscResourceProperty -Name VMRolePublisher -Type String -Attribute Write
    New-xDscResourceProperty -Name OSDiskSearch -Type String -Attribute Required -ValueMap 'LatestApplicable','LatestApplicableWithFamilyName','Specified' -Values 'LatestApplicable','LatestApplicableWithFamilyName','Specified'
    New-xDscResourceProperty -Name OSDiskFamilyName -Type String -Attribute write
    New-xDscResourceProperty -Name OSDiskRelease -Type String -Attribute Write
    New-xDscResourceProperty -Name NetworkReference -Type String -Attribute Required
    New-xDscResourceProperty -Name VMRoleParameters -Type Hashtable -Attribute Write
    New-xDscResourceProperty -Name TokenSource -Type String -Attribute Required -ValueMap 'ASPNET','ADFS' -Values 'ASPNET','ADFS'
    New-xDscResourceProperty -Name TokenURL -Type String -Attribute Required
    New-xDscResourceProperty -Name TokenPort -Type Uint16 -Attribute Write -Description 'Specify custom port to acquire token. Defaults for ADFS: 443, ASP.Net: 30071'
    New-xDscResourceProperty -Name Port -Type Uint16 -Attribute Write -Description 'Specify API port. Default: 30006'
) -Force