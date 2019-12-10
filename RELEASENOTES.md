# Version 1.1.5

* Added Get-SVTdisk command. The information here was mostly already available from Get-SVThardware, but this command makes it much more readily available. It includes a list of physical disks with health, serial number, firmware and capacity. In addition, the storage kit installed is shown, derived from the host model, as well as number and capacity of the disks.
* Updates to the Start-SVTshutdown command. This command now automatically reconnects to another operational virtual controller in the federation, if one exists, following the shutdown of the target virtual controller. It also automatically detects if the target virtual controller is the last one operational in the cluster and correctly handles shutting it down. Finally, the command waits for the virtual controller to completly shutdown (allowing the storage IP to failover), which ensures proper sequential shutdown. This allows you to pass in multiple hosts at once. For example, to shutdown an entire cluster and be prompted before doing so, enter the following:

```powershell
    PS C:\> Get-SVThost -cluster <target cluster> | Start-SVTshutdown -Confirm:$True
```
  In addition, the  command now has -Confirm and -Whatif paramaters.

* Added an automatic reconnect feature so that the session is reestablished and the token is updated following the inactive timeout of the session 
* Fixed dates for all cmdlets to support locale on the local computer.
* Fixed a bug with the Get-SVTBackup -Latest parameter. This command will now correctly show the latest backup per VM from the list of backups requested.
* Updated the appearance of charts

# Version 1.1.4

* Added -Chart parameter to the Get-SVTmetric and Get-SVTcapacity cmdlets - Note this will only work with Windows PowerShell 5.1. PowerShell Core (6.0) doesn't support Microsoft Chart Controls
* Added -Force parameter to the Get-SVTmetric to override the default chart limit
* Improved Get-SVTbackup so that API filters are used properly - This should improve performance and remove some weird results.
* Performance updates to Get-SVTvm and bug fixes to Get-SVTclusterConnected
* Renamed Stop-SVTovc to Start-SVTshutdown
* Renamed Undo-SVTovcShutdown to Stop-SVTshutdown and implemented this cmdlet 
* Renamed Get-SVTovcShutdownStatus to Get-SVTshutdownStatus
* Minor display format changes for some cmdlets to accomodate long hostnames
* Verbose automatically turned on for some commands

# Version 1.1.3

* MIT license added
* Published to PowerShell Gallery
* Signed code so the module will run using 'Remote Signed' PowerShell execution policy
* Added minor change to support 3.7.9
* Bug fixes

# Version 1.1.2

* Added Get-SVTmetric and Get-SVTcapacity cmdlets
* Added maximum limits for Get-SVTbackup and Get-SVTvm as per release notes
* Added support for 3.7.8
* Bug fixes

# Version 1.1.1

* Added most of the "post", "delete" and "put" commands
* Added default display formatting for most HPE SimpliVity objects
* Bug fixes

# Version 1.1.0

* First release written using version 3.7.7. Module contains most of the "get" cmdlets only.
