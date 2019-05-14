 # HPE SimpliVity PowerShell Module

This PowerShell module utilises the HPE SimpliVity REST API to display information about a SimpliVity federation. 

The module contains the following exported cmdlets:

* Connect-SVT                         * New-SVTpolicy
* Copy-SVTbackup
* Get-SVTbackup
* Get-SVTcapacity
* Get-SVTcluster
* Get-SVTclusterConnected
* Get-SVTdatastore
* Get-SVTdatastoreComputeNode
* Get-SVThardware
* Get-SVThost
* Get-SVTmetric
* Get-SVTovcShutdownStatus
* Get-SVTpolicy
* Get-SVTpolicyScheduleReport
* Get-SVTtask
* Get-SVTthroughput
* Get-SVTtimezone
* Get-SVTversion
* Get-SVTvm
* Get-SVTvmReplicaSet
* Lock-SVTbackup
* Move-SVTvm
* New-SVTbackup
* New-SVTclone
* New-SVTdatastore

Publish-SVTdatastore
Remove-SVTbackup
Remove-SVTdatastore
Remove-SVThost
Remove-SVTpolicy
Remove-SVTpolicyRule
Rename-SVTbackup
Rename-SVTpolicy
Resize-SVTdatastore
Restore-SVTvm
Resume-SVTpolicy
Set-SVTbackupRetention
Set-SVTdatastorePolicy
Set-SVTtimezone
Set-SVTvmPolicy
Start-SVTvm
Stop-SVTbackup
Stop-SVTovc
Stop-SVTvm
Suspend-SVTpolicy
Undo-SVTovcShutdown
Unpublish-SVTdatastore
Update-SVTbackupUniqueSize

Some of the cmdlets have parameters to filter on specific properties, like -VM and -Datastore. All cmdlets output a Powershell custom object which can be piped to other commands like Select-Object, Where-Object, Out-GridView and Export-CSV, etc. Refer to the cmdlet help for details.

As an example, I have also created a PowerShell script to shutdown an entire HPE SimpliVity cluster. The script uses this module together with VMware PowerCLI to connect to vCenter and any OmniStack VC in the federation to shutdown the VMs, the appropriate OVC(s) and  host(s) in the specified cluster. The prerequisite for this to work is that, obviously, vCenter cannot be running on a VM in the cluster you're shutting down. The idea of this script is to gracefully shutdown the cluster in a power failure and could be executed from the UPS software (again, running outside the cluster). 

![This is what the script looks like](/Media/Image%20037.png)

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

