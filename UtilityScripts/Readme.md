This folder contains PowerShell scripts that utilise the HPESimpliVity module to do specific things.

## DailyWeeklyMonthlyReport.ps1

This script creates/displays reports for daily, weekly, monthly and failed backups, based on the backup create date.

## MismatchedVMpolicy.ps1

This script displays VMs that have different backup policies to the backup policy assigned to the datastore on which they reside. You may want to track this and change the VMs' backup policy to match the current datastore policy.

Policies are assigned to VMs using the default policy associated with the datastore when the VM is created. If you then move the VM to a different datastore, the VM retains its original backup policy, unless you explicitely change it.  

## ShutdownHPESimplivityCluster.ps1

This script is used to shutdown an entire HPE SimpliVity cluster. The script uses the HPE SimpliVity module together with VMware PowerCLI to connect to vCenter to shutdown the VMs, then connects to a OmniStack virtual Controller (OVC) in the federation and shuts down the appropriate OVC(s) and  host(s) in the specified cluster.

For the purposes of illustration, the script has a concept of VM shutdown order, using VMware tags on the VMs. The idea here would be to shutdown application servers first, then databases and finally, critical infrastructure servers, like Active Directory and DNS.

The prerequisite for this to work is that vCenter cannot be running on a VM in the cluster you're shutting down. The main purpose of this script is to gracefully shutdown the specified cluster following a power failure to ensure there is no data loss. It could be executed from UPS software that supports running external commands (again, the UPS software must be running outside of the cluster). 

Here's an example of what it does:
![This is what the script looks like](/Media/Image%20037.png)


