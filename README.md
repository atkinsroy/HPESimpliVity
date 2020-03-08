 # HPE SimpliVity PowerShell Module

This PowerShell module utilizes the HPE SimpliVity REST API to display information and manage a HPE SimpliVity federation. It works by connecting to any HPE OmniStack Virtual Controller in your environment. With the release of HPE SimpliVity V4.0, you can now also connect to a Management Virtual Appliance, which is recommended.

All cmdlets are written as advanced cmdlets, with extensive comment based help and the majority have the ability to accept the output from another cmdlet as input. Most cmdlets that show information have filtered parameters to limit the number of objects returned. The cmdlets have also been written to adhere to the current recommendations with the REST API. For example, limit the number of records when returning virtual machines and backup objects.

Most "Get" commands display default properties; use Format-List or Select-Object to show the  all. For example:
```powershell
    PS C:\> Connect-SVT -OVC 192.168.1.11 -Credential $Cred
    PS C:\> Get-SVThost
    
    HostName      DataCenterName    ClusterName   FreeSpaceGB    ManagementIP   StorageIP     FederationIP 
    --------      --------------    -----------   -----------    ------------   ---------     ------------
    srvr1.sg.com  SunGod            Production1         2,671    192.168.1.11   192.168.2.1   192.168.3.1
    srvr2.sg.com  SunGod            Production1         2,671    192.168.1.12   192.168.2.2   192.168.3.2
    srvr3.sg.com  SunGod            DR1                 2,671    192.170.1.11   192.170.2.1   192.170.3.1
   
    PS C:\>Get-SVThost -HostName 192.168.1.1 | Select-Object *
    
    PolicyEnabled            : True
    ClusterId                : 3baba7ec-6d02-4fb6-b510-5ce19cd9c1d0
    StorageMask              : 255.255.255.0
    Model                    : HPE SimpliVity 380 Series 4000
    HostName                 : srvr1.sg.com
    .
    .
    .
```
## Update V2.0.28 new features

* Supports the new features in HPE SimpliVity 4.0.0. Specifically, the ability to add and show external store information (HPE StoreOnce is currently supported) and the ability to backup/restore to/from external stores. 
* Added support for multiple value parameters to most of the "GET" commands. This works best when connected to a Management Virtual Appliance (MVA) rather than an OmniStack Virtual Controller (OVC). (See known issues below)
* Added support for new HPE SimpliVity hardware models.

Refer to the release notes ![here](/RELEASENOTES.md) for more details.

The module contains 54 exported cmdlets, divided into the following feature categories:

Backups | Backup Policy | Datastore & Cluster
--- | --- | ---
Stop-SVTbackup | Suspend-SVTpolicy | Get-SVTcluster
Rename-SVTbackup | Rename-SVTpolicy | Get-SVTclusterConnected
Lock-SVTbackup | Resume-SVTpolicy | Get-SVTdatastore
Remove-SVTbackup | New-SVTpolicy | Publish-SVTdatastore
New-SVTbackup | Remove-SVTpolicy | Remove-SVTdatastore
Copy-SVTbackup | Get-SVTpolicy | Resize-SVTdatastore
Get-SVTbackup | New-SVTpolicyRule | New-SVTdatastore 
Set-SVTbackupRetention | Update-SVTpolicyRule | Unpublish-SVTdatastore
Update-SVTbackupUniqueSize | Remove-SVTpolicyRule | Get-SVTdatastoreComputeNode
&nbsp; | Get-SVTpolicyScheduleReport | Set-SVTdatastorePolicy
&nbsp; | &nbsp; | Get-SVTexternalStore
&nbsp; | &nbsp; | New-SVTexternalStore


&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; VM &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; | &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Host &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Utility &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
---------------- | --- | ---
New-SVTclone | Get-SVThardware | Connect-SVT
Get-SVTvm | Get-SVThost | Get-SVTcapacity
Start-SVTvm | Remove-SVThost | Get-SVTmetric
Move-SVTvm | Start-SVTshutdown | Get-SVTtask
Restore-SVTvm | Stop-SVTshutdown | Get-SVTtimezone
Stop-SVTvm | Get-SVTshutdownStatus | Set-SVTtimezone
Set-SVTvmPolicy | Get-SVTthroughput | Get-SVTversion
Get-SVTvmReplicaSet | Get-SVTdisk

## Requirements

* PowerShell V5.1 and above. (note: the chart features do not work with PowerShell Core 6.0 or PowerShell 7.0)
* The IP address and the credentials of an authorized OmniStack user account.
* Tested with HPE SimpliVity V4.0.0. The module should be compatible with older versions, but has not been tested. 

## Installation

* Install or update the HPESimplivity module from the PowerShell Gallery, using the following respective commands:
```powershell
    PS C:\> Install-Module -Name HPESimpliVity
    # or
    PS C:\> Update-Module -Name HPESimpliVity
```
The module is signed, so it will work with an execution policy set to Remote Signed.

* Restart Powershell to load the module, or type:
```powershell
    PS C:\> Import-Module HPESimpliVity -Force
```
* After this, the module will automatically load in new PowerShell sessions. Issue the following commands to confirm:
```powershell
    PS C:\> Get-Command -Module HPESimpliVity
    PS C:\> Get-Help Connect-SVT
    PS C:\> Get-Help Get-SVTbackup
```
* Once installed, you're ready to connect to the OmniStack virtual controller or Management Virtual Appliance, as follows:
```powershell
    PS C:\> $Cred = Get-Credential -Message 'Enter OVC/MVA Credentials'
    PS C:\> Connect-SVT -OVC <IP or FQDN of an OVC or MVA> -Credential $Cred
    PS C:\> Get-SVThost
```
Or, if you need to run commands in batch (non-interactively), save your credentials to a file first:

```powershell
    PS C:\> $Cred = Get-Credential -Username 'administrator@vsphere.local' | Export-Clixml .\OVCcred.XML 
```
and then in your script, import the credential:
```powershell
    PS C:\> $Cred = Import-CLIXML .\OVCcred.XML
    PS C:\> Connect-SVT -OVC <IP or FQDN of an OVC or MVA> -Credential $Cred
    PS C:\> Get-SVThost
```

**Note:** You must login with an admin account (e.g. an account with the vCenter Admin Role for VMware environments).

## Known issues with V4.0.0 of the API (With HPESimpliVity 2.0.28)

The API has some documented and undocumented issues:
* OMNI-69918: GET /virtual_machines fails with OutOfMemoryError. The HPE SimpliVity module limits the number of VMs returned to 8000, as per the recommendation
* OMNI-46361: REST API GET opertions for backup objects and sorting filtering constraints. Comma separated list of values for filtering is not supported. Some properties do not support case insensitive filter option. This issue does not appear to effect connections made to Management Virtual Appliances. For example, the following commands all work when connected to an MVA:

````powershell
    PS C:\>  Get-SVTbackup -VmName Vm1,Vm2,Vm3
    PS C:\>  Get-SVTbackup -Destination Cluster1,Cluster2
    PS C:\>  Get-SVTbackup -Destination StoreOnce-Data01,StoreOnce-Data02
    PS C:\>  Get-SVTbackup -Datastore DS01,DS02
    PS C:\>  Get-SVTbackup -BackupName Test1,Test2
    PS C:\>  Get-SVTbackup -BackupId a9e82f..., 0ef1bd...
````

* Backups stored on external stores cannot be deleted if the VM has been deleted, with a backup not found error. This does not apply to backups stored on clusters. This restriction is specific to the API; the CLI command svt-backup-delete works as expected for external store backups.
* the PUT /policies/\<policyid\>/rules/\<ruleid\> API call (implementmented in Update-SVTpolicyRule) doesn't work as expected in some circumstances. Changing a rules' destination is not supported (this is documented), but in addition, changing the consistancy type to anything other than NONE or DEFAULT doesn't work. If you attempt to change the consistenct type to VSS, for example, the command is ignored. In this scenario, a work around would be to delete the rule entirely from the policy using Remove-SVTpolicyRule and then use New-SVTpolicyRule to create a new rule with the desired destination, consistenecy type and other settings.
* Using GET /backups with a specific cluster_id (implemented as Get-SVTbackup -DestinationName \<ClusterName\>) will result in backups located on the specified cluster AND external stores too. This issue only applies when connected to an OVC; calls to an MVA work as expected. In either case, filtering on an external store works as expected (e.g. Get-SVTbackup -DestinationName ExternalStore1)

## Things to do
* Test using PowerShell 7.0 (Windows and Linux)

If you would like to keep up to date with changes, please subscribe to receive notifications.
