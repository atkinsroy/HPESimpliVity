
# HPE SimpliVity PowerShell Module

![PowerShell Gallery](https://img.shields.io/powershellgallery/v/HPESimplivity?style=for-the-badge&logo=powershell)
![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/HPESimplivity?style=for-the-badge)

![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/HPESimplivity?style=for-the-badge)



This PowerShell module utilizes the HPE SimpliVity REST API to manage a SimpliVity federation. It connects to any HPE SimpliVity Virtual Appliance in your environment. With the release of HPE SimpliVity V4.0.0 and above, you can now also implement and connect to a Management Virtual Appliance, which is recommended. The cmdlets adhere to the current HPE recommendations with the REST API. For example, limiting the number of records when returning virtual machine and backup objects.

Example usage:

```
    PS C:\> Connect-Svt -VirtualAppliance 192.168.1.11 -Credential $Cred
    PS C:\> Get-SvtHost




    HostName      DataCenterName  ClusterName  FreeSpaceGB  ManagementIP  StorageIP    FederationIP
    --------      --------------  -----------  -----------  ------------  ---------    ------------
    srvr1.sg.com  SunGod          Production1        2,671  192.168.1.11  192.168.2.1  192.168.3.1
    srvr2.sg.com  SunGod          Production1        2,671  192.168.1.12  192.168.2.2  192.168.3.2
    srvr3.sg.com  SunGod          DR1                2,671  192.170.1.11  192.170.2.1  192.170.3.1
```

## Latest Update

Refer to the [release notes](/RELEASENOTES.md) for more details.

The module contains 58 commands, divided into the following feature categories:

Datastore | Backup | Backup Policy
:--- | :--- | :---
Get-SvtDatastore | Copy-SvtBackup | Get-SvtPolicy
Get-SvtDatastoreComputeNode | Get-SvtBackup | Get-SvtPolicyScheduleReport
Get-SvtExternalStore | Get-SvtFile | New-SvtPolicy
New-SvtDatastore | Lock-SvtBackup | New-SvtPolicyRule
New-SvtExternalStore | New-SvtBackup | Remove-SvtPolicy
Publish-SvtDatastore | Remove-SvtBackup | Remove-SvtPolicyRule
Remove-SvtDatastore | Rename-SvtBackup | Rename-SvtPolicy
Remove-SvtExternalStore | Restore-SvtFile | Resume-SvtPolicy
Resize-SvtDatastore | Set-SvtBackupRetention | Suspend-SvtPolicy
Set-SvtDatastorePolicy | Stop-SvtBackup | Update-SvtPolicyRule
Set-SvtExternalStore | Update-SvtBackupUniqueSize |
Unpublish-SvtDatastore |
 ||
**Cluster & Utility** | **Host** | **Virtual Machine**
Connect-Svt | Get-SvtDisk | Get-SvtVm
Get-SvtCapacity | Get-SvtHardware | Get-SvtVmReplicaSet
Get-SvtCluster | Get-SvtHost | Move-SvtVm
Get-SvtClusterConnected | Get-SvtShutdownStatus | New-SvtClone
Get-SvtMetric | Get-SvtThroughput | Restore-SvtVm
Get-SvtTask | Remove-SvtHost | Set-SvtVm
Get-SvtTimezone | Start-SvtShutdown | Start-SvtVm
Get-SvtVersion | Stop-SvtShutdown | Stop-SvtVm
Set-SvtCluster

Refer to the [documentation](/Docs) for more information.

## Requirements

* Windows PowerShell V5.1 or PowerShell Core V7.x (PowerShell Core V6.x is not recommended)
* The IP address of a Simplivity Virtual Appliance and the credentials of an authorized user account
* The module has been tested with the lastest version of HPE SimpliVity and should be compatible with older versions (but has not been tested)

## Installation

* Install the HPESimplivity module from the PowerShell Gallery using the following command:

```PowerShell
    PS C:\> Install-Module -Name HPESimpliVity
```

* Once installed, you're ready to connect to an SVA or MVA, as follows:

```PowerShell
    PS C:\> $Cred = Get-Credential -Message 'Enter credentials'
    PS C:\> Connect-Svt -VirtualAppliance <IP or FQDN of an SVA or MVA> -Credential $Cred
```

* Or, if you need to run commands in batch (non-interactively), save your credentials to a file first:

```PowerShell
    PS C:\> $Cred = Get-Credential -Username 'administrator@vsphere.local' | Export-Clixml .\cred.XML 
```

and then in your script, import the credential for a new session:

```PowerShell
    PS C:\> $Cred = Import-CLIXML .\cred.XML
    PS C:\> Connect-Svt -VA 192.168.1.11 -Credential $Cred
    PS C:\> Get-SvtHost
```

**Note:** You must login with an admin account (e.g. an account with the vCenter Admin Role for VMware environments).

## Known issues with the REST API

The API has some documented and undocumented issues:

* OMNI-69918: GET /virtual_machines fails with OutOfMemoryError. The HPE SimpliVity module limits the number of VMs returned to 8000, as per the recommendation
* OMNI-46361: REST API GET operations for backup objects and sorting filtering constraints. Comma separated lists for filtering backup objects is not supported when connecting to OmniStack Virtual Controllers. Comma separated lists CAN be used when connected to a Management Virtual Appliance. For example, the following commands all work when connected to an MVA:

```PowerShell
    PS C:\> Get-SvtBackup -VmName Vm1,Vm2,Vm3
    PS C:\> Get-SvtBackup -Destination Cluster1,Cluster2
    PS C:\> Get-SvtBackup -Destination StoreOnce-Data01,StoreOnce-Data02
    PS C:\> Get-SvtBackup -Datastore DS01,DS02
    PS C:\> Get-SvtBackup -BackupName Test1,Test2
    PS C:\> Get-SvtBackup -BackupState FAILED,SAVING,QUEUED
    PS C:\> Get-SvtBackup -BackupId a9e82f..., bef1bd...
```

* Backups stored on external stores cannot be deleted if the VM has been deleted, with a "backup not found" error. This does not apply to backups stored on SimpliVity clusters. This restriction is specific to the API; the CLI command svt-backup-delete works as expected for external store backups.
* the PUT /policies/\<policyid\>/rules/\<ruleid\> API call (implemented in Update-SvtPolicyRule) doesn't work as expected in some circumstances. Changing a rules' destination is not supported (this is documented). In addition, changing the consistency type to anything other than NONE or DEFAULT doesn't work. If you attempt to change the consistency type to VSS, for example, the command is ignored. In this scenario, a work around would be to delete the rule entirely from the policy using Remove-SvtPolicyRule and then use New-SvtPolicyRule to create a new rule with the desired destination, consistency type and other settings.
* Using GET /backups with a specific cluster_id (implemented as Get-SvtBackup -DestinationName \<ClusterName\>) will result in both backups located on the specified cluster AND external stores being displayed. This issue only applies when connected to an SVA; calls to an MVA work as expected. In either case, filtering on an external store works as expected (e.g. Get-SvtBackup -DestinationName ExternalStore1)

If you would like to keep up to date the latest features, please subscribe to receive notifications. Updates are published to the PowerShell Gallery at the same time.
