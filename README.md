 # HPE SimpliVity PowerShell Module

This PowerShell module utilizes the HPE SimpliVity REST API to display information and manage a HPE SimpliVity federation. It works by connecting to any HPE OmniStack Virtual Controller in your environment.

All cmdlets are written as advanced cmdlets, with extensive comment based help and the majority have the ability to accept the output from another cmdlet as input. Most cmdlets that show information have filtered parameters to limit the number of objects returned. The cmdlets have also been written to adhere to the current recommendations with the REST API. For example, limit the number of records to 500 when returning virtual machines and backup objects.

Most "Get" commands provide too many properties to show at once, so default display properties are shown. All properties are still accessible, by piping to Format-List or Select-Object -property *

For example:
```powershell
    PS C:\> Connect-SVT -OVC 192.168.1.11 -Credential $Cred
    PS C:\> Get-SVThost
    
    HostName      DataCenterName    ClusterName   FreeSpaceGB    ManagementIP   StorageIP     FederationIP 
    --------      --------------    -----------   -----------    ------------   ---------     ------------
    192.168.1.1   SunGod            Production1         2,671    192.168.1.11   192.168.2.1   192.168.3.1
    192.168.1.2   SunGod            Production1         2,671    192.168.1.12   192.168.2.2   192.168.3.2
    192.170.1.1   SunGod            DR1                 2,671    192.170.1.11   192.170.2.1   192.170.3.1
   
    PS C:\>Get-SVThost -HostName 192.168.1.1 | Select-Object *
    
    PolicyEnabled            : True
    ClusterId                : 3baba7ec-6d02-4fb6-b510-5ce19cd9c1d0
    StorageMask              : 255.255.255.0
    Model                    : HPE SimpliVity 380 Series 4000
    .
    .
    .
```


The module contains 52 exported cmdlets, divided into the following feature categories:

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
Move-SVTvm | Start-SVTshutdown | Get-SVTtask
Restore-SVTvm | Stop-SVTshutdown | Get-SVTtimezone
Stop-SVTvm | Get-SVTshutdownStatus | Set-SVTtimezone
Set-SVTvmPolicy | Get-SVTthroughput | Get-SVTversion
Get-SVTvmReplicaSet | Get-SVTdisk

## Update V1.1.5 new features

Show physical disk and storage kit information with the new Get-SVTdisk command.

Properly shutdown a host, cluster or the entire federation, with the updated Start-SVTshutdown command. This function is accompanied with the utility script called ShutdownHPESimpliVityCluster.ps1 in the UtilityScripts folder, which will shutdown virtual machines in a specific order, then shuts down the virtual controllers and finally places the hosts into maintenance mode before shutting them down.

## Update V1.1.4 features

With V1.1.4, the Get-SVTmetric cmdlet now produces charts. You can create charts for clusters, hosts and virtual machines. Here's
how it works:

```powershell
    PS C:\> Get-SVThost | Select-Object -First 1 | Get-SVTmetric -Hour 48 -Chart
```

This will create a single chart for the first host in the Federation using the specified hourly range. The cmdlet also has a new -Force 
parameter. By default, up to five charts are created, one for each object passed in. If there are more objects than this in
the pipeline, the cmdlet will issue a warning. You can override this limit with the -Force switch. There is potential to create a
lot of charts with Get-SVTvm. 

Here is a sample metric chart:

![Here is a sample metric chart](/Media/SVTmetric-sample.png)

Similarly, Get-SVTcapacity also has a new -Chart switch. Use the following command to create a chart for each host in the federation.

```powershell
    PS C:\> Get-SVTcapacity -Chart
```

This is a sample capacity chart:

![Here is a sample capacity chart](/Media/SVTcapacity-sample.png)

**Note:** Both of these commands require Windows PowerShell (tested with V5.1 only). They will not work with PowerShell Core V6.x / V7.0 (.NET Core does not support Microsoft Chart Controls).

## Requirements

* PowerShell V5.1 and above. (note that the chart features do not work with PowerShell Core 6.0/7.0)
* The IP address and the credentials of an authorized OmniStack user account.
* Tested with HPE OmniStack 3.7.7 and above. Both VMware and Hyper-V versions have been tested.

## Installation

* Install the HPESimplivity module from the PowerShell Gallery, using the following command:
```powershell
    PS C:\> Install-Module -Name HPESimpliVity -RequiredVersion 1.1.5
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
* Once installed, you're ready to connect to the OmniStack virtual controller, as follows:
```powershell
    PS C:\> $Cred = Get-Credential -Message 'Enter OVC Credentials'
    PS C:\> Connect-SVT -OVC <IP or FQDN of an OmniStack Virtual Controller> -Credential $Cred
    PS C:\> Get-SVThost
```
Or, if you need to run commands in batch (non-interactively), save your credentials to a file first:

```powershell
    PS C:\> $Cred = Get-Credential -Username 'administrator@vsphere.local' | Export-Clixml .\OVCcred.XML 
```
and then in your script, import the credential:
```powershell
    PS C:\> $Cred = Import-CLIXML .\OVCcred.XML
    PS C:\> Connect-SVT -OVC <IP or FQDN of an OmniStack Virtual Controller> -Credential $Cred
    PS C:\> Get-SVThost
```

**Note:** You must login with an admin account (e.g. an account with the vCenter Admin Role for VMware environments).

## Things to do
* Test using PowerShell Core 6.0 (Windows and Linux)

If you would like to keep up to date with changes, please subscribe to receive notifications.
