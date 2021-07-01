# HPE SimpliVity PowerShell Module Release Notes

## Version 2.1.29

* Added support for new HPE SimpliVity V4.1.0 features:

  * Ability to create and show single replica datastores with New-SvtDatastore and Get-SvtDatastore respectively.
  * Ability to enable and disable Intelligent Workload Optimizer within a SimpliVity cluster. For example:

````PowerShell
    Set-SvtCluster -EnableIWO:$true -ClusterName TwoDogs
````

* Removed Set-SvtTimezone command. This has been replaced with:

````PowerShell
    Set-SvtCluster -TimeZone 'Australia/Sydney' -ClusterName TwoDogs
````

* Removed references 'OVC' within the module. The '-OVC' parameter for the Connect-Svt command is replaced with '-VirtualAppliance' or '-VA'. The '-OVC' parameter will continue to work, but is depreciated.

* Performance improvements with a number of cmdlets that accept hostname as input. Formally, an API call was made to enumerate fully qualified hostnames. This information is now cached in a global variable called $SvtHost. As a result commands such as Get-Disk and Get-Hardware run faster in large environments.

* Some formatting changes; default property changes and color added to some objects to highlight things like failed disks and failed backups.

* Bug fixes.

## Version 2.1.27

* Refactored the Get-SvtBackup command. The -Sort parameter has been added to support displaying backups sorted by a single, specified property. Accepted properties are VmName, BackupName, BackupSize, CreateDate, ExpiryDate, ClusterName and DatastoreName. The default sort property is now CreateDate, which is more useful than the REST API default, which sorts on backup name. In addition a new -Ascending parameter has been added to reverse the sort order, if required.

* Fixed a bug with how backup names are displayed when using PowerShell 7.x (Core). Policy based backup names are now correctly displayed as UTC date/time strings rather than a locally converted date object.

## Version 2.1.25

* Refactored the Restore-SvtVm command. Formally, this command supported restoring multiple VMs at once, based on the backup objects passed in from Get-SvtBackup. Restored VMs retain the original VM names with a timestamp suffix to ensure naming uniqueness. The command now supports restoring a single backup with a specified VM name. This will only work for the first backup object passed into the command. Subsequent restores will not be attempted and an error will be displayed. For example:

````PowerShell
    PS C:\> Get-SvtBackup -VM VM1 -Limit 1 | Restore-SvtVm -NewVmName NewVM1
````

This command will restore the last backup of VM1 to a new VM called NewVM1. By default, this VM will be located on the same datastore as the original, but can be created on an alternative datastore using -DatastoreName.

* Refactored the Get-SvtBackup command. The -Date parameter formally accepted just a date and showed the whole 24 hour range of backups. Now, the -Date parameter can also accept a date and time specified in the locale for your system.
For example:

````PowerShell
    PS C:\> Get-SvtBackup -VM VM1,VM3 -Date '12/12/2020 10:00:00 AM'
````

This command will show the backup with the specified creation date for the two virtual machines.

## Version 2.1.24

* Added 'RemainingLife' property to Get-SvtDisk. This shows up as a percentage.
* Refactored the Get-SvtBackup command. Added the ability to use the -ExpiresBefore and -ExpiresAfter parameters along with the -Date parameter. For Example:

````PowerShell
    PS C:\> Get-SvtBackup -Date 18/07/2020 -ExpiresAfter '22/08/2020 10:00:00 PM'
````

## Version 2.1.23

* PowerShell Core support has been added. Specifically tested PowerShell v7.0.0, v7.0.1 and v7.1.0. PowerShell v7.0.1 has a bug preventing charts from being created ("Exception calling 'SaveImage'"). The other two versions work as expected. PowerShell Core v6.x versions have not been tested.
* A new optional parameter to Get-SvtMetric called -ChartProperty has been added to allow you to create charts with a subset of the available metrics
* HPE branding has been added to the charts produced by Get-SvtMetric and Get-SvtCapacity:

Metrics | Capacity
:--- | :---
![Here is a sample branded metric chart](/Media/SvtMetric-branded.png) | ![Here is a sample branded capacity chart](/Media/SvtCapacity-branded.png)

## Version 2.1.18

* Added a new parameter -RetentionHour to the New-SvtBackup and Set-SvtBackupRetention commands
* Added -MinSizeGB and -MaxSizeGB to the Get-SvtBackup command
* Locale bug fix in the Get-SvtBackup and Get-SvtDisk commands
* Performance refactoring

## Version 2.1.15

* Added the ability to display backed up file information within HPE SimpliVity backups and to perform file-level restores from the command line, using two new commands; Get-SvtFile and Restore-SvtFile respectively
* Renamed Set-SVTvmPolicy to Set-SVTvm and added the ability to set user credentials on virtual machines for Microsoft Volume Shadow Copy Service (VSS) backups using this command
* Added a new parameter called -ImpactReportOnly to several commands; Set-SVTvm, New-SvtPolicyRule, Update-SvtPolicyRule and Remove-SvtPolicyRule. Instead of performing the policy based action, the command displays a report that shows the projected daily backup rates and new total retained backups given the frequency and retention settings if the change is subsequently made
* Updated Remove-SvtBackup to remove multiple backups using a single task. This is much more efficient even if you have a small number of backups to remove
* Updated Get-SvtBackup with many more parameters, i.e. -Date, -CreateAfter, -CreateBefore, -ExpiresAfter, -ExpiresBefore, -ClusterName, -BackupState and -BackupType. Improved the ability to specify multiple parameters at once to refine which backups are queried
* Updated the -All parameter for the Get-SvtBackup command to return all backup records. This bypasses the previous restriction of the -Limit parameter being set to 3000 and is achieved by making multiple calls to the API with an offset. This command can take a long time to finish; specifying additional parameters to restrict the output is recommended
* Removed the -Latest parameter from Get-SvtBackup. This effected the performance of Get-SvtBackup generally, whether this parameter was used or not. There is a work around in the example help for this command that displays the same results
* Performance refactoring and bug fixes

## Version 2.1.4

* Added support for the new features in HPE SimpliVity V4.0.1
* Added two new commands; Set-SvtExternalStore and Remove-SvtExternalStore. The first command allows you to change the credentials used by the HPE StoreOnce appliance for the specified external store. The second command allows you to un-register the specified external store
* Added a new parameter -RetentionHour to New-SvtPolicyRule and Update-SvtPolicyRule. You can now specify retention by day or by hour; if both are specified, hour takes precedence
* Added RetentionHour and RetentionMinute properties to Get-SvtPolicy
* Added AvailabilityZoneEffective and AvailabilityZonePlanned properties to Get-SvtHost

## Version 2.0.28

* Removed -ApplicationConsistent switch from the policy and backup commands. Application consistency is assumed to be false if ConsistencyType is set to NONE. For all other consistency types (DEFAULT and VSS), application consistency is true. This removes confusion, with multiple parameters doing similar things
* Added multi-value support for most "Get" commands, where supported by the API. For example:

````PowerShell
    PS C:\> Get-SVTvm -ClusterName cluster1,cluster2 -State ALIVE,REMOVED,DELETED
    PS C:\> Get-SvtBackup -VmName Vm1,Vm2,Vm3
    PS C:\> Get-SvtHost Host1,Host2,Host3
````

**Note:** multi-value parameters do not work for Get-SvtBackup when connected to an OVC; they do work when connected to an MVA.

* Added a new -PolicyName parameter to Get-SVTvm
* Added a new utility script called CreateClone.ps1. This script will clone multiple VMs or clone one VM multiple times or both at once
* Bug fixes

## Version 2.0.24

* Added support for new hardware models. Get-SvtDisk supports the new Gen 10 H and Gen 10 G models
* Tested the HPESimpliVity module with the new Management Virtual Appliance in V4.0.0
* Refactored the cmdlets that deal with external stores. Cmdlets now support a single parameter called -DestinationName rather than -ClusterName and -ExternalStoreName. This is a breaking change
* Added default parameters to New-SvtClone and Get-SvtClusterConnected cmdlets
* Refactored Get-SvtBackup to improve performance, specifically with the -Hour parameter
* Added additional new attributes provided by API to some cmdlets
* Bug fixes

## Version 2.0.16

* Added support for new HPE SimpliVity V4.0.0 features. Specifically, the ability to create new and show external stores with two new cmdlets (New-SvtExternalStore and Get-SvtExternalStore, respectively). In addition, the following cmdlets have been updated to support external stores:

  * Get-SvtBackup - displays 'DestinationName' showing either a SimpliVity cluster or an external store
  * New-SvtBackup - has a new parameter -ExternalStoreName to specify the destination for a new backup
  * Copy-SvtBackup - has a new parameter -ExternalStoreName to specify the destination for an existing backup
  * New-SvtPolicyRule - has a new parameter -ExternalStoreName to specify the destination for a new policy rule
  * Update-SvtPolicyRule - has a new parameter -ExternalStoreName to update an existing policy rule

**Note:** Remove-SvtBackup and Restore-SVTvm work without change with backups stored on external stores, although restoring with the -RestoreToOriginal switch enabled is currently not supported with external store backups.

**Note:** The new HPE StoreOnce Catalyst datastore must be added via the StoreOnce management console with appropriate permissions prior to registering it as a SimpliVity external store

* Added support for more meaningful run time errors, by determining the error message embedded in the body of the response from the API and passing this through in the cmdlets
* Hostname is now accepted as well as the fully qualified domain name for those cmdlets that accept the hostname parameter. Hostname can be entered in the form 'host' as well as 'host.domain.com'
* Refactored some of the cmdlets to simplify the code. Some cmdlets, like Get-SVTvm and New-SvtClone do not accept input from the pipeline any more. Get-SVTvm -Hostname 'host' can be used to filter on a specific hostname
* New-SvtClone now accepts a -CloneName parameter and will only perform a single clone operation on one VM. The previous functionality (cloning multiple VMs once, cloning one VM multiple times or both) will be moved to a utility script to be used in conjunction with the updated New-SvtClone cmdlet
* Renamed Set-SVTPolicyRule to New-SvtPolicyRule
* Autosized columns added for most SimpliVity objects. For performance reasons, cmdlets that produce a lot of objects, like Get-SvtMetric and Get-SvtBackup are not autosized
* Added some additional properties to cluster objects related to the new supported Arbiter configurations available in V4.0.0
* Bug fixes

## Version 1.1.5

* Added the Get-SvtDisk command. The information here was mostly already available from Get-SvtHardware, but this command makes it much more readily available. It includes a list of physical disks with health, serial number, firmware and capacity. In addition, the installed storage kit is shown, derived from the host model, as well as number and capacity of the disks.
* Updates to the Start-SvtShutdown command. This command now detects if the target virtual controller is the last one operational in the cluster and correctly handles shutting it down. It also automatically reconnects to another operational virtual controller in the federation, if one exists, following the shutdown of the target virtual controller. Finally, the command waits for the virtual controller to completely shutdown (allowing the storage IP to failover), which ensures proper sequential shutdown. This allows you to pass in multiple hosts at once. For example, to shutdown an entire cluster and be prompted before doing so, enter the following:

```PowerShell
    PS C:\> Get-SvtHost -cluster <target cluster> | Foreach-Object {Start-SvtShutdown -HostName $_.Hostname -Confirm:$True}
```

  In addition, the  command now has -Confirm and -WhatIf parameters

* Added an automatic reconnect feature so that the session is reestablished and the token is updated following the inactivity timeout
* Dates for all cmdlets now support the locale on the local computer
* Fixed a bug with the Get-SVTBackup -Latest parameter. This command will now correctly show the latest backup per VM from the list of backup objects requested
* Updated the appearance of charts

## Version 1.1.4

* Added -Chart parameter to the Get-SvtMetric and Get-SvtCapacity cmdlets. For example:

```PowerShell
    PS C:\> Get-SvtHost | Select-Object -First 1 | Get-SvtMetric -Hour 48 -Chart
```

This will create a single chart for the first host in the Federation using the specified hourly range. The cmdlet also has a new -Force parameter. By default, up to five charts are created, one for each object passed in. If there are more objects than this in the pipeline, the cmdlet will issue a warning. You can override this limit with the -Force switch. There is potential to create a lot of charts with Get-SVTvm.

Similarly, Get-SvtCapacity also has a new -Chart switch. Use the following command to create a chart for each host in the federation.

```PowerShell
    PS C:\> Get-SVTHost server01 | Get-SvtCapacity -Chart
```

* Improved Get-SvtBackup so that API filters are used properly - This improves performance and removes some weird results
* Performance updates to Get-SVTvm and bug fixes to Get-SvtClusterConnected
* Renamed Stop-SvtOvc to Start-SvtShutdown
* Renamed Undo-SvtOvcShutdown to Stop-SvtShutdown and implemented this cmdlet
* Renamed Get-SvtOvcShutdownStatus to Get-SvtShutdownStatus
* Minor display format changes for some cmdlets to accomidate long hostnames
* Verbose automatically turned on for some commands

## Version 1.1.3

* MIT license added
* Published to PowerShell Gallery
* Signed code so the module will run using 'Remote Signed' PowerShell execution policy
* Added minor change to support 3.7.9
* Bug fixes

## Version 1.1.2

* Added Get-SvtMetric and Get-SvtCapacity cmdlets
* Added maximum limits for Get-SvtBackup and Get-SVTvm as per release notes
* Added support for 3.7.8
* Bug fixes

## Version 1.1.1

* Added most of the "post", "delete" and "put" commands
* Added default display formatting for most HPE SimpliVity objects
* Bug fixes

## Version 1.1.0

* First release written using version 3.7.7. The module contains most of the "get" cmdlets only
