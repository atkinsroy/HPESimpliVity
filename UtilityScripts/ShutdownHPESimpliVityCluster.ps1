##############################################################################
# ShutdownHPESimplivityCluster.ps1
#
# Description:
#   Shutdown the specified HPE SimpliVity cluster. A typical use of this script 
#   would be to execute this from UPS console when a power failure is detected.
# 
# 
#   Download:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   VERSION 2.0, used with HPESimpliVity PowerShell Module V1.1.5 or above
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext Services
#
##############################################################################

<#
(C) Copyright 2019 Hewlett Packard Enterprise Development LP

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
#>

<#
.SYNOPSIS
    Shutdown an entire HPE SimpliVity cluster
.DESCRIPTION
    This script will shutdown all the virtual machines in the specified cluster, followed by the HPE Omnistack
    Virtual Controllers. Finally, it will place the ESXi hosts into maintenance mode and then shut them down.

    The intention for this script is to execute a safe shutdown of the specifed cluster, following a power failure.
    
    Requirements:
    1. You must be able to connect to the vCenter server where the SimpliVity cluster is registered throughout the entire process. 
       A managmement cluster running vCenter would be the ideal scenario.

    1. VMware PowerCLI must be installed locally. You can install this using:
            Install-Module -Name VMware.PowerCLI

    2. HPESimpliVity PowerShell module V1.1.5 or above must be installed locally. You can install this using:
            Install-Module -Name HPEsimpliVity -RequiredVersion 1.1.5

    3. In order to power off the VMs with a specific order in the target cluster, you can optionally implement VM tagging in vCEnter. For example, the
       PowerCLI commands required to implement the default configuration are:
            New-TagCategory -Name "Shutdown" -Description "Shutdown Virtual Machines in a specific Order" -Cardinality Single -EntityType virtualmachine
            New-tag -Name ShutdownOrder1 -Category shutdown -Description "Critical/Infrastructure servers - Shutdown last"
            New-tag -Name ShutdownOrder2 -Category shutdown -Description "Backend servers - Shutdown after application servers"
            New-tag -Name ShutdownOrder3 -Category shutdown -Description "Application servers - Shutdown first"
       You can implement as many tags as you need, as long as you follow a standard naming convention. This can be altered using variables at the beginning
       of the script. Using VM tags is optional, but highly recommended to ensure VMs are shutdown in a desired sequence.

       Then assign these tags to your VMs using New-TagAssignment. For example:
            get-vm | where name -match "^RHEL8-0[1|2|3]" | New-TagAssignment -Tag ShutdownOrder1
            get-vm | where name -match "^RHEL8-0[4|5|6]" | New-TagAssignment -Tag ShutdownOrder2
            get-vm | where name -match "^RHEL8-0[7|8|9]" | New-TagAssignment -Tag ShutdownOrder3
       Untagged virtual machines are powered off last.

    4. You must use the default names for Omnistack virtual controllers (must start with 'OmniStackVC'). If you change their names, this script will fail.

    Constraints:
    1. This script supports VMware clusters only. Hyper-V clusters are not supported

    2. vCenter (on a VCSA or on Windows Server) must be running outside of the target VMware cluster.

.PARAMETER OVC
    A HPE Omnistack Virtual Controller in the SimpliVity Federation where the target vSphere cluster resides. Note that the virtual
    controller does not need to be within the target cluster - the script will identify the appropriate virtual controllers to shut them
    down.
.PARAMETER Cluster
    The VMware vSphere / HPE SimpliVity cluster to shutdown
.PARAMETER Force
    An optional parameter which is required to actually perform the cluster shutdown. Without this, the script just reports about what it would do, 
    including what order it would power off VMs, shutdown virtual controllers and finally turn off the ESXi hosts. In either case, the script writes
    output to a log file.
.EXAMPLE
    PS C:\> .\ShutdownHPESimpliVityCluster.ps1 -OVC 192.168.1.21 -ClusterName Cluster01

    This command will report on the shutdown tasks only, including connecting to the specified virtual controller, connecting to the correct 
    vCenter (PowerCLI is a pre-requisite), iterating through powered on VMs to power them off, shutting down all the virtual controllers in the 
    specfiied cluster and finally placing the hosts into maintenance mode and powering them off.

    NOTE: The specified virtual controller does not need to be in the specified cluster. This script will reconnect to each
    appropriate virtual controller in turn to shut them down.

    NOTE: This script will prompt you to enter your current credentials the first time you run it. They are saved in the current
    folder in a file called OVCcred.xml so that the script can run in batch mode. This allows execution from UPS software following a power
    outage. The account specified must be a member of the Administrators role in vCenter. You will need to recreate the credential file if you
    change your password.

.EXAMPLE
    PS C:\> .\ShutdownHPESimpliVityCluster.ps1 -OVC 192.168.1.21 -ClusterName Cluster01 -Force

    Execute the shutdown with the -Force parameter. Assuming you have entered your current credentials at least once before (by running in
    report mode, for example), no other prompts are made, so be sure this is what you want to do.
.INPUTS
    System.String
.OUTPUTS
    System.String
.NOTES
#>
[cmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "A HPE OmniStack Virtual Controller in the Federation")]
    [System.String]$OVC,

    [Parameter(Mandatory = $true, Position = 2)]
    [System.String]$ClusterName,

    [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Without -Force, the script just reports without doing anything")]
    [Switch]$Force
)

#####################################################################################
# Change these variables to suit your environment

# VM tag names (case sensitive), shown in the order of shutdown, in this example are:
# ShutdownOrder3, ShutdownOrder2, ShutdownOrder1 and then other (untagged) VMs last.

[string]$TagName = 'ShutdownOrder'
[int]$NumberOfTags = 3

# After each group of VMs with a specific tag have been powered off wait a specified 
# time, in seconds. The default is 30 seconds:

[int]$WaitBetweenTag = 30

# Prior to shutting down the virtual controllers, check one last time that all
# VMs are statefully powered off. If this time is exceeded, power off the VM rather 
# than shutting down the guest. The default is 2 minutes:

[int]$TotalWaitSec = 180
####################################################################################

# Helper function to write messages to the console and to a log file.
Function Write-Log {
    Param (
        [Parameter(Position = 0)]
        [String]$Message,

        [Parameter(Position = 1)]
        [Byte]$LogType = 0
    )
    $LogDate = Get-Date -Format "yyyy-MM-dd-HH:mm:ss"
    $MessageType = @("[INFO]", "[WARNING]", "[ERROR]")
    "$LogDate $($MessageType[$LogType]) $Message" | Add-Content -Path $Logfile

    # Not using Start-Transcript to support the use of color in interactive sessions.
    # Start-Transcript is used during virtual controller shutdown to capture verbose stream output 
    $MessageColour = @("Green", "Yellow", "Red")
    Write-Host "$LogDate " -ForegroundColor Cyan -NoNewline
    Write-Host "$($MessageType[$LogType]) " -ForegroundColor $MessageColour[$LogType] -NoNewline
    Write-Host $Message -ForegroundColor White
}

# Create a logfile location
$CurrentPath = (Get-Location).Path
$FileDate = Get-Date -Format 'yyMMddhhmm'
$LogFile = "$CurrentPath\ShutdownHPESimpliVityCluster-$FileDate.log"


# Obtain credentials using the same admin account for both vCenter and the Omnistack Virtual Controllers.
$CredFile = "$CurrentPath\OVCcred.xml"
if (Test-Path $CredFile) {
    $Cred = Import-Clixml $CredFile
}
else {
    # No credential file found, so create one. Obviously, this is no good if running non-interactively, so create one beforehand
    $Cred = Get-Credential -Message "Enter the credentials of an account with the vCenter Administrators Role"
    $Cred | Export-Clixml $CredFile # to use next time
}

# Connect to the virtual controller and enumerate the list of hosts in the target cluster, as well as the vCenter instance being used by the target cluster
try {
    Connect-SVT -OVC $OVC -Credential $Cred -ErrorAction Stop | Out-Null
    $HostList = Get-SVTHost -ClusterName $ClusterName -ErrorAction Stop
    $vCenterIP = $HostList | Select -First 1 -ExpandProperty HypervisorManagementIP
    $vCenterName = $HostList | Select -First 1 -ExpandProperty HypervisorManagementName
    Write-Log "Connected to HPE Omnistack Virtual Controller: $OVC"
}
catch {
    Write-Log "Error connecting to the HPE OmniStack Virtual Controller : $($_.Exception.Message)" 2
    throw "Error connecting to the specified HPE OmniStack Virtual Controller : $($_.Exception.Message)"
}

# Connect to vCenter instance used by the target cluster.
try {
    Connect-VIServer -Server $vCenterIP -Credential $Cred -ErrorAction Stop | Out-Null
    Write-Log "Connected to vCenter Server: $vCenterName ($vCenterIP)"
}
catch {
    Write-Log "Error connecting to vCenter server: $($_.Exception.Message)" 2
    throw "Error connecting to vCenter server: $($_.Exception.Message)"
}

# Shutdown VMs using tags in reverse order. Skip any unfound shutdown order tags.
[array]$TaggedVM = @()
$NumberOfTags..1 | Foreach-Object {   
    [string]$Tag = "$TagName$_"
    try {
        $VMcluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
        $VMhost = $VMcluster | Get-VMhost -ErrorAction Stop # used later to shutdown hosts
        $VMlist = $VMcluster | Get-VM -Tag $Tag -ErrorAction Stop | 
        Where-Object Name -notmatch 'OmniStackVC' | 
        Where-Object PowerState -eq 'PoweredOn'
        $VMcount = $VMlist | Measure-Object | Select-Object -ExpandProperty Count
        Write-Log "Found $VMcount powered on VMs on cluster $ClusterName with a shutdown order tag set to $Tag"
    }
    catch {
        if ($_.Exception.Message -match 'Could not find Tag') {
            Write-Log "No VMs with shutdown order tag $Tag found"
        }
        Else {
            Write-log "$_.Exception.Message" 2
            throw $_.Exception.Message
        }
    }

    if ($VMcount -gt 0) {
        foreach ($VM in $VMlist) {
            Write-Log "Found $($VM.Name) with shutdown order tag set to $Tag"
            
            # Keep track of the tagged VMs we're powering off here so we don't try to power them off again later.
            $TaggedVM += $($VM.Name)
            
            try {
                if ($Force) {
                    $Response = $VM | Stop-VMGuest -Confirm:$false -ErrorAction Stop
                    Write-Log "$($Response.VM) (tools version:$($response.ToolsVersion)) is shutting down" 
                }
                else {
                    $VM | Stop-VMGuest -Whatif -ErrorAction Stop
                }
            }
            catch {
                if ($_.Exception.Message -match 'Cannot complete operation because VMware Tools is not running') {
                    Write-Log "Cannot shutdown the guest on $($VM.Name) because VMware Tools are not running" 1
                }
                else {
                    Write-Log "Could not shutdown VM $($VM.Name): $_.Exception.Message" 2
                    # Don't throw error. We can at least try to shutdown as many VMs as possible
                }
            }
        }
        if ($Force) {
            Write-Log "Waiting $WaitBetweenTag Seconds for VMs with a shutdown order tag set to $Tag to finish shutting down..."
            Start-Sleep -Seconds $WaitBetweenTag
        }
    }  
}

# Now that we've powered off all the tagged VMs, shutdown any other VMs left running. We ignore tagged VMs and the virtual controllers
Write-Log "Looking for any other powered on VMs on cluster $ClusterName with no/unrecognised tags"
try {
    $VMlist = $VMcluster | 
    Get-VM -ErrorAction Stop | 
    Where-Object Name -NotMatch 'OmniStackVC' | 
    Where-Object Name -NotIn $TaggedVM |
    Where-Object PowerState -eq 'PoweredOn'
}
catch {
    Write-Log "$_.Exception.Message" 2
    throw $_.Exception.Message
}           
foreach ($VM in $VMlist) {
    Write-Log "Found $($VM.Name) with no shutdown order tag"
    try {
        if ($Force) {
            $Response = $VM | Stop-VMGuest -Confirm:$false -ErrorAction Stop
            Write-Log "$($Response.VM) (tools version:$($response.ToolsVersion)) is shutting down" 
        }
        else {
            $VM | Stop-VMGuest -Whatif -ErrorAction Stop
        }
    }
    catch {
        if ($_.Exception.Message -match 'Cannot complete operation because VMware Tools is not running') {
            Write-Log "Cannot shutdown the guest on $($VM.Name) because VMware Tools are not running" 1
        }
        else {
            Write-Log "Could not shutdown VM $($VM.Name): $_.Exception.Message" 2

        }
    }
}


# Shutdown the virtual controllers, but wait until all other VMs are shutdown first
[int]$WaitSec = 0
if ($Force) {
    do {
        try {
            $VMpoweredOn = $VMcluster | 
            Get-VM -ErrorAction Stop | 
            Where-Object Name -NotMatch 'OmniStackVC' | 
            Where-Object PowerState -eq 'PoweredOn' | 
            Measure-Object | 
            Select-Object -ExpandProperty Count
            if ($VMpoweredOn) {
                if ($WaitSec -ge $TotalWaitSec) {
                    $VMname = $VMcluster | 
                    Get-VM -ErrorAction Stop | 
                    Where-Object Name -NotMatch 'OmniStackVC' | 
                    Where-Object PowerState -eq 'PoweredOn' |
                    Select-Object -ExpandProperty Name
                    $VMname | ForEach-Object {
                        Write-Log "Could not shutdown the guest OS on VM $_ within the assigned time ($TotalWaitSec seconds); powering off $_" 1
                        Stop-VM -VM $_ -Confirm:$false | Out-Null
                    }
                    break
                }
                else {
                    $WaitSec += 10
                    Write-Log "Waited $WaitSec of $TotalWaitSec seconds to allow $VMpoweredOn VMs to shutdown"
                    Start-Sleep -Seconds 10
                }
            }
        }
        catch {
            Write-Log "Unexpected error when attempting to finalize VM powered off" 2
            throw "Unexpected error when attempting to finalize VM powered off"
        }
    
    } while ($VMpoweredOn)

    # NOTE: Here would be good a place to attempt a remote backup, if you have multiple sites, your infrastructure (i.e. network) is still running and 
    # you have enough UPS battery to try it. Its not implemented, but you could do something as simple as the following in small environments.
    # Get-SVTvm | New-SVTbackup -ClusterName <destination cluster>
    # and then keep checking with Get-SVTtask until State = 'COMPLETED' for all backup tasks before shutting down the virtual controllers.

    # Shutdown the virtual controllers now
    try {
        $HostList | ForEach-Object {
            Write-Log "Shutting down the HPE Omnistack virtual controller on host $($_.Hostname)..."
            # Using Start-Transcript capture verbose and error streams to log file.
            Start-Transcript -Path $LogFile -Append | Out-Null
            $response = Start-SVTshutdown -HostName $_.Hostname -Confirm:$False -ErrorAction Stop
            Stop-Transcript | Out-Null
            Write-Log "Successfully shutdown HPE Omnistack virtual controller on host $($_.Hostname)"
        }
    }
    catch {
        Write-Log "Failed to shutdown the HPE Omnistack Virtual Controller $($_.Exception.Message)" 2
        throw $_.Exception.Message
    }
}
else {
    try {
        $HostList | Foreach-Object {
            Write-Log "Shutting down the HPE Omnistack virtual controller on host $($_.Hostname)..."
            # Using Start-Transcript capture verbose and error streams to log file.
            Start-Transcript -Path $LogFile -Append | Out-Null
            Start-SVTshutdown -HostName $_.Hostname -Whatif -ErrorAction Stop
            Stop-Transcript | Out-Null
            Write-Log "Successfully shutdown HPE Omnistack virtual controller on host $($_.Hostname)"
        }
    }
    catch {
        Write-Log "Failed to shutdown the HPE Omnistack Virtual Controller $($_.Exception.Message)" 2
        throw $_.Exception.Message
    }
}

# Wait until the virtual controllers are shutdown - no timer here, keep trying until UPS stops.
if ($Force) {
    do {
        Write-Log "Waiting 10 seconds to allow the HPE OmniStack Virtual Controllers to completely shutdown"
        Start-Sleep -Seconds 10
        try {
            $VMname = $VMcluster | Get-VM -ErrorAction Stop | Where-Object PowerState -eq 'PoweredOn'
        }
        catch {
            Write-Log "Failed to shutdown the HPE Omnistack Virtual Controller $($_.Exception.Message)" 2
            throw $_.Exception.Message
        }
    } while ($VMname)
    

    # Shutdown the host(s)
    try {
        Write-Log "Placing hosts into maintenance mode..." 
        $Response = $VMhost | Set-VMHost -State Maintenance -Confirm:$false -ErrorAction Stop
        $Response | Foreach-object {
            Write-Log "$_ is in connection state of $($_.ConnectionState) and a power state of $($_.PowerState)"
        }
        Write-Log "Shutting down hosts..."
        $Response = $VMhost | Stop-VMHost -Confirm:$false -ErrorAction Stop
        $Response | Foreach-object {
            Write-Log "$_ is in connection state of $($_.ConnectionState) and a power state of $($_.PowerState)"
        }
    }
    catch {
        Write-Log "Could not shutdown a least one host : $($_.Exception.Message)" 2
        throw $_.Exception.Message
    }
}
else {
    Write-Log "Placing hosts into maintenance mode..." 
    $VMhost | Set-VMHost -State Maintenance -Whatif
    Write-Log "Shutting down hosts..."
    $VMhost | Stop-VMHost -Whatif
}
Write-Log "Created a log file called: $LogFile"
Write-Log "Done"