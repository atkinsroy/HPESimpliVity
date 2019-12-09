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