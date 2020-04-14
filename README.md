 # HPE SimpliVity PowerShell Module

This PowerShell module utilizes the HPE SimpliVity REST API to display information and manage a HPE SimpliVity federation. It works by connecting to any HPE OmniStack Virtual Controller in your environment.

All cmdlets are written as advanced cmdlets, with comment based help and the majority have the ability to accept the output from another cmdlet as input. Most cmdlets that show information have filtered parameters to limit the number of objects returned. The cmdlets have also been written to adhere to the current recommendations with the REST API. For example, limit the number of records to 500 when returning virtual machines and backup objects.

Most "Get" commands provide too many properties to show at once, so default display properties are shown. All properties are still accessible, by piping to Format-List or Select-Object -property *

For example:
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
## Update V2.1.4 new features

* Supports the new features in HPE SimpliVity 4.0.1. Specifically, the ability to delete external stores and reset the credentials of external stores 
* Added support to create and update backup policies with a rentention specified in hours. The ability to specify rentention in days still exists. 

Refer to the release notes ![here](/RELEASENOTES.md) for more details.

The module contains 56 exported cmdlets, divided into the following feature categories:

Datastore | Backup Policy | Backups
--- | --- | ---
Get-SVTdatastore | Suspend-SVTpolicy | Stop-SVTbackup
New-SVTdatastore | Rename-SVTpolicy | Rename-SVTbackup
Remove-SVTdatastore | Resume-SVTpolicy | Lock-SVTbackup
Resize-SVTdatastore | New-SVTpolicy | Remove-SVTbackup
Publish-SVTdatastore | Remove-SVTpolicy | New-SVTbackup
Unpublish-SVTdatastore | Get-SVTpolicy | Copy-SVTbackup
Get-SVTdatastoreComputeNode | New-SVTpolicyRule | Get-SVTbackup
Set-SVTdatastorePolicy | Update-SVTpolicyRule | Set-SVTbackupRetention
Get-SVTexternalStore | Remove-SVTpolicyRule | Update-SVTbackupUniqueSize
New-SVTexternalStore | Get-SVTpolicyScheduleReport 
Set-SVTexternalStore
Remove-SVTexternalStore

Cluster & Utility | Host | VM
--- | --- | ---
Get-SVTcluster | Get-SVThost | Get-SVTvm
Get-SVTclusterConnected | Get-SVThardware | Move-SVTvm
Connect-SVT | Remove-SVThost | New-SVTclone
Get-SVTcapacity | Start-SVTshutdown | Restore-SVTvm
Get-SVTmetric | Stop-SVTshutdown | Start-SVTvm
Get-SVTtask | Get-SVTshutdownStatus | Stop-SVTvm
Get-SVTtimezone | Get-SVTthroughput | Set-SVTvmPolicy
Set-SVTtimezone | Get-SVTdisk | Get-SVTvmReplicaSet
Get-SVTversion

## Requirements

* PowerShell V5.1 and above. (note that the chart features do not work with PowerShell Core 6.0 or PowerShell 7.0)
* The IP address and the credentials of an authorized OmniStack user account.
* Tested with HPE SimpliVity V4.0.1. The module should be compatible with older versions, but has not been tested. 

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

## Known issues with V4.0.1 of the API (With HPESimpliVity 2.1.4)

The API has some documented and undocumented issues:
* OMNI-69918: GET /virtual_machines fails with OutOfMemoryError. The HPE SimpliVity module limits the number of VMs returned to 8000, as per the recommendation
* OMNI-46361: REST API GET opertions for backup objects and sorting filtering constraints. Comma separated list of values for filtering is not supported. Some properties do not support case insensitive filter option. The HPE SimpliVity module does not allow you to enter multiple values for filtering options, as per the recommendation. This issue does not appear to effect connections made to Management Virtual Appliances. For example, the following commands all work when connected to an MVA:

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

If you would like to keep up to date with changes, please subscribe to receive notifications.
