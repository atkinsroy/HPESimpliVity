 # HPE SimpliVity PowerShell Module

This PowerShell module utilises the HPE SimpliVity REST API to display information about a SimpliVity federation. 

The module contains the following exported cmdlets:

* Get-SVTBackup
* Get-SVTCluster
* Get-SVTDatastore
* Get-SVTHost
* Get-SVTPolicy
* Get-SVTVM
* Get-SVTOVCShutdownStatus
* Stop-SVTOVC
* Connect-SVT

Some of the cmdlets have parameters to filter on specific properties, like -VM and -Datastore. All cmdlets output a Powershell custom object which can be piped to other commands like Select-Object, Where-Object, Out-GridView and Export-CSV, etc. Refer to the cmdlet help for details.

As an example, I have also created a PowerShell script to shutdown an entire HPE SimpliVity cluster. The script uses this module together with VMware PowerCLI to connect to vCenter and any OmniStack VC in federation to shutdown the VMs, the appropriate OVC(s)and the host(s) in the specified cluster. The prequisite for this to work is that, obviously, vCenter cannot be running on a VM in the cluster you're shutting down. The idea of this script is to gracefully shutdown the cluster in a power failure and could be executed from the UPS software (again, running outside the cluster). 

## Installation

* Copy the files to %userprofile%\Documents\WindowsPowershell\Modules\HPESimpliVity. (This assumes you are using Windows Powershell 3.0 or above. Note that the module was created and tested with V5.1).

* Edit the HPESimpliVity.psm1 file and enter the username and password for your virtual controller

* Restart Powershell

* Issue the following commands:
```powershell
    Get-Command -Module HPESimpliVity
    Get-Help Get-SVTBackup
```

## Things To Do

* The module mostly covers just the REST API GET commands. More POST commands need to be added, focusing on the important ones first, such New-SVTbackup and Move-SVTVM.

* Test using PowerShell Core 6.0 (Windows and Linux).

* I was originally using ps1xml files to determine the format of the commands. I've removed this for now, limiting the number properties to four. Once I've added all of the other commands, I'll re-introduce this. 
