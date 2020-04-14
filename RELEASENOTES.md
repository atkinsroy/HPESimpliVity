# Version 2.1.4

* Added support for the new features in HPE SimpliVity V4.0.1
* Added two new commands, Set-SVTexternalStore and Remove-SVTexternalStore. The first command allows you to change the credentials used by the HPE StoreOnce appliance for the specified external store. The second command allows you to unregister the specified external store
* Added a new parameter -RetentionHour to New-SVTpolicyRule and Update-SVTpolicyRule. You can now specify retention by day or by hour; if both are specified, hour takes precedence
* Added RetentionHour and RetentionMinute properties to Get-SVTpolicy
* Added AvailabilityZoneEffective and AvailabilityZonePlanned properties to Get-SVThost

# Version 2.0.28

* Removed -ApplicationConsistent switch from the policy and backup commands. Application consistency is assumed to be false if ConsistencyType is set to NONE. For all other consistency types (DEFAULT and VSS), application consistency is true. This removes confusion, with multiple parameters doing similar things.
* Added multi-value support for most "Get" commands, where supported by the API. For example, 

````powershell
    PS C:\> Get-SVTvm -ClusterName cluster1,cluster2 -State ALIVE,REMOVED,DELETED
    PS C:\> Get-SVTbackup -VmName Vm1,Vm2,Vm3
    PS C:\> Get-SVThost Host1,Host2,Host3
````
Note: multi-value parameters do not work for Get-SVTbackup when connected to an OVC; they do work when connected to an MVA.

* Added a new -PolicyName parameter to Get-SVTvm
* Added a new utility script called CreateClone.ps1. This script will clone multiple VMs or clone one VM multiple times or both at once
* Bug fixes

# Version 2.0.24

* Added support for new hardware models. Get-SVTdisk supports the new Gen 10 H and Gen 10 G models
* Tested the HPEsimpliVity module with the new Management Virtual Appliance in V4.0.0
* Refactored the cmdlets that deal with external stores. Cmdlets now support a single parameter called -DestinationName rather than -ClusterName and -ExternalStoreName. This is a breaking change
* Added default parameters to New-SVTclone and Get-SVTclusterConnected cmdlets
* Refactored Get-SVTbackup to improve performance, specfically with the -Hour parameter
* Added additional new attributes provided by API to some cmdlets
* Bug fixes


# Version 2.0.16

* Added support for new HPE SimpliVity V4.0.0 features. Specifically, the ability to create new and show external stores with two new cmdlets (New-SVTexternalStore and Get-SVTexternalStore, respectively). In addition, the following cmdlets have been updated to support external stores:
    * Get-SVTbackup - displays 'DestinationName' showing either a SimpliVity cluster or an external store
    * New-SVTbackup - has a new parameter -ExternalStoreName to specify the destination for a new backup
    * Copy-SVTbackup - has a new parameter -ExternalStoreName to specfiy the destination for an existing backup
    * New-SVTpolicyRule - has a new parameter -ExternalStoreName to specify the destination for a new policy rule
    * Update-SvtPolicyRule - has a new parameter -ExternalStoreName to update an existing policy rule

Note: Remove-SVTbackup and Restore-SVTvm work without change with backups stored on external stores, although restoring with the -RestoreToOrignal switch enabled is currently not supported with external store backups.

Note: The new HPE StoreOnce Catalyst datastore must be added via the StoreOnce management console with appropriate permissions prior to registering it as a SimpliVity external store
* Added support for more meaningful run time errors, by determining the error message embedded in the body of the response from the API and passing this through in the cmdlets
* Hostname is now accepted as well as the fully qualified domain name for those cmdlets that accept the hostname parameter. Hostname can be entered in the form 'host' as well as 'host.domain.com'
* Refactored some of the cmdlets to simplify the code. Some cmdlets, like Get-SVTvm and New-SVTclone do not accept input from the pipeline any more. Get-SVTvm -Hostname 'host' can be used to filter on a specific hostname
* New-SVTclone now accepts a -CloneName parameter and will only perform a single clone operation on one VM. The previous functionality (cloning multiple VMs once, cloning one VM multiple times or both) will be moved to a utility script to be used in conjunction with the updated New-SVTclone cmdlet
* Renamed Set-SVTPolicyRule to New-SVTpolicyRule
* Autosized columns added for most SimpliVity objects. For performance reasons, cmdlets that produce a lot of objects, like Get-SVTmetric and Get-SVTbackup are not autosized
* Added some additional properties to cluster objects related to the new supported Arbiter configurations available in V4.0.0
* Bug fixes


# Version 1.1.5

* Added the Get-SVTdisk command. The information here was mostly already available from Get-SVThardware, but this command makes it much more readily available. It includes a list of physical disks with health, serial number, firmware and capacity. In addition, the installed storage kit is shown, derived from the host model, as well as number and capacity of the disks.
* Updates to the Start-SVTshutdown command. This command now detects if the target virtual controller is the last one operational in the cluster and correctly handles shutting it down. It also automatically reconnects to another operational virtual controller in the federation, if one exists, following the shutdown of the target virtual controller. Finally, the command waits for the virtual controller to completely shutdown (allowing the storage IP to failover), which ensures proper sequential shutdown. This allows you to pass in multiple hosts at once. For example, to shutdown an entire cluster and be prompted before doing so, enter the following:

```powershell
    PS C:\> Get-SVThost -cluster <target cluster> | Foreach-Object {Start-SVTshutdown -HostName $_.Hostname -Confirm:$True}
```
  In addition, the  command now has -Confirm and -Whatif parameters

* Added an automatic reconnect feature so that the session is reestablished and the token is updated following the inactivity timeout 
* Dates for all cmdlets now support the locale on the local computer
* Fixed a bug with the Get-SVTBackup -Latest parameter. This command will now correctly show the latest backup per VM from the list of backup objects requested
* Updated the appearance of charts

# Version 1.1.4

* Added -Chart parameter to the Get-SVTmetric and Get-SVTcapacity cmdlets. For example:

```powershell
    PS C:\> Get-SVThost | Select-Object -First 1 | Get-SVTmetric -Hour 48 -Chart
```

This will create a single chart for the first host in the Federation using the specified hourly range. The cmdlet also has a new -Force parameter. By default, up to five charts are created, one for each object passed in. If there are more objects than this in the pipeline, the cmdlet will issue a warning. You can override this limit with the -Force switch. There is potential to create a lot of charts with Get-SVTvm. 

Here is a sample metric chart:

![Here is a sample metric chart](/Media/SVTmetric-sample.png)

Similarly, Get-SVTcapacity also has a new -Chart switch. Use the following command to create a chart for each host in the federation.

```powershell
    PS C:\> Get-SVTHost server01 | Get-SVTcapacity -Chart
```

This is a sample capacity chart:

![Here is a sample capacity chart](/Media/SVTcapacity-sample.png)

**Note:** Both of these commands require Windows PowerShell (tested with V5.1 only). They will not work with PowerShell Core V6.x / V7.0 (.NET Core does not support Microsoft Chart Controls).

* Improved Get-SVTbackup so that API filters are used properly - This improves performance and removes some weird results
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

* First release written using version 3.7.7. The module contains most of the "get" cmdlets only
