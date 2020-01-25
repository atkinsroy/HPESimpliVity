# Version 2.0.0

* Added support for new HPE SimpliVity V4.0.0 features. Specifically, the ability to create new and show external stores with two new cmdlets (New-SVTexternalStore and Get-SVTexternalStore, respectively). In addition, the following cmdlets have been updated to support external stores:
    * Get-SVTbackup - displays 'DestinationName' showing either a SimpliVity cluster or the external store
    * New-SVTbackup - has a new parameter -ExternalStoreName
    * Copy-SVTbckup - has a new parameter -ExternalStoreName
    * New-SVTpolicyRule - has a new parameter -ExternalStoreName
    * Update-SvtPolicyRule - has a new parameter -ExternalStoreName

Note: Remove-SVTbackup and Restore-SVTvm work without change with backups stored on external stores.

Note: The new Catalyst datastore must be added via the StoreOnce management console with appropriate permissions prior to registering it as a SimpliVity external store.
* Added support for more meaningful run time errors, by determining the error message embedded in the body of the responce from the API and passing this through in the cmdlets.
* Hostname is now accepted as well as the fully qualified domain name for those cmdlets that accept the hostname parameter. Users can now enter hostname in the form <host> as well as <host.domain.com>.
* Refactored some of the cmdlets to simplify the code. Some cmdlets, like Get-SVTvm and New-SVTclone do not accept input from the pipeline any more. Get-SVTvm -Hostname <host> can be used to filter on a specific hostname.
* New-SVTclone now accepts a -CloneName parameter and will only perform a single clone operation on one VM. The previous functionality (cloning multiple VMs once, cloning one VM multiple times or both) will be moved to a utility script to be used in conjunction with the updated New-SVTclone.  
* Renamed Set-SVTPolicyRule to New-SVTpolicyRule
* Ausized columns added for most SimpliVity objects. For performance reasons, cmdlets that produce a lot of objects, like Get-SVTmetric, are not autosized. 
* Bug fixes


# Version 1.1.5

* Added the Get-SVTdisk command. The information here was mostly already available from Get-SVThardware, but this command makes it much more readily available. It includes a list of physical disks with health, serial number, firmware and capacity. In addition, the installed storage kit is shown, derived from the host model, as well as number and capacity of the disks.
* Updates to the Start-SVTshutdown command. This command now detects if the target virtual controller is the last one operational in the cluster and correctly handles shutting it down. It also automatically reconnects to another operational virtual controller in the federation, if one exists, following the shutdown of the target virtual controller. Finally, the command waits for the virtual controller to completely shutdown (allowing the storage IP to failover), which ensures proper sequential shutdown. This allows you to pass in multiple hosts at once. For example, to shutdown an entire cluster and be prompted before doing so, enter the following:

```powershell
    PS C:\> Get-SVThost -cluster <target cluster> | Foreach-Object {Start-SVTshutdown -HostName $_.Hostname -Confirm:$True}
```
  In addition, the  command now has -Confirm and -Whatif parameters.

* Added an automatic reconnect feature so that the session is reestablished and the token is updated following the inactivity timeout 
* Dates for all cmdlets now support the locale on the local computer.
* Fixed a bug with the Get-SVTBackup -Latest parameter. This command will now correctly show the latest backup per VM from the list of backup objects requested.
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
