 # HPE SimpliVity PowerShell Module V1.1.0

This PowerShell module utilises the HPE SimpliVity REST API to display information and manage a SimpliVity federation and works by connecting to any OmniStack Virtual Controller in your environment.

The module uses V1.11 of the Rest API, which comes with HPE SimpliVity 3.7.8 and includes the latest support for displaying Infosight information on SimpliVity clusters, but it works with 3.7.7 too. 

All cmdlets are written as advanced cmdlets, with extensive comment based help and most have the ability to accept the output from another cmdlet as input. Most cmdlets that show information have filtering parameters to limit the number of objects returned. The cmdlets have also been written to adhere to the current recommendations with the REST API, for example limiting the number of records to 500 when returning virtual machines and backup objects.

Most "Get" commands provide way too many properties to show at once, so ps1xml files have been introduced into this version, to provide default display properties. All properties are still accessible, by piping to Format-List or Select-Object -property *

For Example:
```powershell
    PS C:\>Connect-SVT -OVC 192.168.1.11 -Credential $Cred
    PS C:\>Get-SVThost
    
    HostName      DataCenterName    ClusterName   FreeSpaceGB    ManagementIP   StorageIP     FederationIP 
    --------      --------------    -----------   -----------    ------------   ---------     ------------
    192.168.1.1   SunGod            Production1         2,671    192.168.1.11   192.168.2.1   192.168.3.1
    192.168.1.2   SubGod            Production1         2,671    192.168.1.12   192.168.2.2   192.168.3.2
   
    PS C:\>Get-SVThost -HostName 192.168.1.1 | Format-List
    
    PolicyEnabled            : True
    ClusterId                : 3baba7ec-6d02-4fb6-b510-5ce19cd9c1d0
    StorageMask              : 255.255.255.0
    Model                    : HPE SimpliVity 380 Series 4000
    .
    .
    .
```


The module currently contains 51 exported cmdlets, in the following feature categories:

Backups | Backup Policy | Datastore & Cluster
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

## Requirements

* PowerShell V3.0 and above. This module was created and tested using PowerShell V5.1.
* The IP address and the credentials of an authorised SimpliVity user account.
* Tested with OmniStack 3.7.8. (Works with 3.7.7 too. Both VMware and Hyper-V have been tested).

## Installation

* Copy all the files to %userprofile%\Documents\WindowsPowershell\Modules\HPESimpliVity. 

Note: the folder structure is important to ensure that PowerShell automatically loads the module.

* Restart Powershell to load the module, or type:

```powershell
    PS C:\>import-module HPESimpliVity -force
```
* After this, the module will automatically load in new PowerShell sessions. Issue the following commands to confirm:
```powershell
    PS C:\>Get-Command -Module HPESimpliVity
    PS C:\>Get-Help Get-SVTBackup
```
* Once installed, you're ready to connect to the OmniStack

## Things To Do
* Test using PowerShell Core 6.0 (Windows and Linux)

* Provide a -Graph parameter on Get-SVTmetric and on Get-SVTcapacity to output a web chart or Excel, or both.
