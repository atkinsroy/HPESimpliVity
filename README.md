 # HPE SimpliVity PowerShell Module

This PowerShell module utilises the HPE SimpliVity REST API to display information and manage a SimpliVity federation.

The module uses V1.11 of the Rest API, which comes with HPE SimpliVity 3.7.8 and includes the latest support for displaying Infosight information on SimpliVity clusters. 

The module currently contains 51 exported cmdlets, in the following feature categories:

Backups | Backup Policy | Datastore & cluster
--- | --- | ---
Stop-SVTbackup | Suspend-SVTpolicy | Get-SVTcluster
Rename-SVTbackup | Rename-SVTpolicy | Get-SVTclusterConnected
Lock-SVTbackup | Resume-SVTpolicy | Get-SVTdatastore
Remove-SVTbackup | New-SVTpolicy | Publish-SVTdatastore
New-SVTbackup | Remove-SVTpolicy | Remove-SVTdatastore
Copy-SVTbackup | Get-SVTpolicy | Resize-SVTdatastore
Get-SVTbackup | Set-SVTpolicyRule | New-SVTdatastore 
Set-SVTbackupRetention | Update-SVTpolicyRule | Unpublish-SVTdatastore
Update-SVTbackupUniqueSize | Remove-SVTpolicyRule | Get-SVTdatastoreComputeNode
&nbsp; | Get-SVTpolicyScheduleReport | Set-SVTdatastorePolicy

&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; VM &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; | &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Host &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; |  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Utility &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 
---------------- | --- | ---
New-SVTclone | Get-SVThardware | Connect-SVT
Get-SVTvm | Get-SVThost | Get-SVTcapacity
Start-SVTvm | Remove-SVThost | Get-SVTmetric
Move-SVTvm | Stop-SVTovc | Get-SVTtask
Restore-SVTvm | Undo-SVTovcShutdown | Get-SVTtimezone
Stop-SVTvm | Get-SVTovcShutdownStatus | Set-SVTtimezone
Set-SVTvmPolicy | Get-SVTthroughput | Get-SVTversion
Get-SVTvmReplicaSet

All cmdlets are written as advanced cmdlets, with extensive comment based help and most with the ability to accept the output from another cmdlet as input. Most cmdlets that show information have filtering parameters to limit the number of objects returned. The cmdlets have also been written to adhere to the current recommendations with the REST API, for example limiting the number of records to 500 when returning virtual machines and backup objects.



## Requirements

* PowerShell V3.0 and above. This module was created and tested using PowerShell V5.1.
* The IP address and the credentials of an authorised SimpliVity user account.
* Tested with OmniStack 3.7.7.

## Installation

* Copy the psm1 file to %userprofile%\Documents\WindowsPowershell\Modules\HPESimpliVity. 

Note: the folder structure is important to ensure that PowerShell automatically loads the module.

* Restart Powershell to load the module, or type:

```powershell
    import-module HPESimpliVity -force
```
* After this, the module will automatically load in new PowerShell sessions. Issue the following commands to confirm:
```powershell
    Get-Command -Module HPESimpliVity
    Get-Help Get-SVTBackup
```

## Things To Do
* The module mostly covers just the REST API GET commands. More POST commands need to be added, focusing on the important ones first, such New-SVTbackup and Move-SVTVM.

* Test using PowerShell Core 6.0 (Windows and Linux).

* I was originally using ps1xml files to determine the format of the commands. I've removed this for now, limiting the number default properties to four. Once I've added all of the other cmdlets, I'll re-introduce this. Tracking property names bacame tiresome.

* Test using the Hyper-V version of SimpliVity

