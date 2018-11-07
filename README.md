 # HPE SimpliVity PowerShell Module

This PowerShell module utilises the HPE SimpliVity REST API to display information about a SimpliVity federation. 

The module contains the following exported cmdlets:

* Get-SVTBackup
* Get-SVTCluster
* Get-SVTDatastore
* Get-SVTHost
* Get-SVTPolicy
* Get-SVTVM

Some of the cmdlets have parameters to filter on specific properties, like -VM and -Datastore. All cmdlets output a Powershell custom object which can be piped to other commands like Select-Object, Where-Object, Out-GridView and Export-CSV, etc. Refer to the cmdlet help for details.

## Installation

* Copy the files to %userprofile%\Documents\WindowsPowershell\Modules\HPESimpliVity. (This assumes you are using Windows Powershell 3.0 or above. Note that the module was created and tested with V5.1).

* Edit the HPESimpliVity.psm1 file and enter the useranme and password for your virtual controller

* Restart Powershell

* Issue the following commands:
```powershell
    Get-Command -Module HPESimpliVity
    Get-Help Get-SVTBackup
```

## Things To Do

* The module covers just the REST API GET commands. The POST commands need to be added, focusing on the important ones first, like backup and move.

* Test using PowerShell Core 6.0 (Windows and Linux).
