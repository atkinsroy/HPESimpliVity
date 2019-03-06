##############################################################################
# ShutdownHPESimplivityCluster.ps1
#
# Description:
#   Shutdown the specified VMware cluster. A typical use of this script would be
#   to execute this from UPS console when a power failure is detected.
#
# Assumptions:
#   You can connect the vCenter server where the SimpliVity cluster is registered
#   throughout the entire process. Its no use powering off the VMs if one of them 
#   is vCenter. A managmement cluster would be the ideal scenario.
#
# Requirements:
#   VMware PowerCLI installed locally
#   HPESimpliVity module installed locally
# 
# Download:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   VERSION 1.0
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext
#
# (C) Copyright 2019 Hewlett Packard Enterprise Development LP 
##############################################################################

<#
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

[cmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Enter the vCenter server local to the specified cluster")]
    [System.String]$vCenterName,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Enter any OmniStack Virtual Controller in the Federation")]
    [System.String]$OVC,

    [Parameter(Mandatory = $true, Position = 2)]
    [System.String]$ClusterName,

    [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Without -Force, the script just reports without doing anything")]
    [Switch]$Force
)

# Help function to write pretty things to the console and a log file
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

    # Yes, puppies are dying. Sue me
    $MessageColour = @("Green", "Yellow", "Red")
    Write-Host "$LogDate " -ForegroundColor Cyan -NoNewline
    Write-Host "$($MessageType[$LogType]) " -ForegroundColor $MessageColour[$LogType] -NoNewline
    Write-Host $Message -ForegroundColor White
}

# Create a logfile location
$CurrentPath = (Get-Location).Path
$FileDate = Get-Date -Format 'yyMMddhhmm'
$LogFile = "$CurrentPath\ShutdownHPESimpliVityCluster-$FileDate.log"


# Obtain credentials using the same admin account for both vCenter and the HPE SimpliVity RESTAPI.
$CredFile = "$CurrentPath\OVCcred.xml"
if (Test-Path $CredFile) {
    $Cred = Import-Clixml $CredFile
}
else {
    # No credential file found, so create one. Obviously no good if running this non-interactively, so create beforehand
    $Cred = Get-Credential -Message "Enter the username and password of a suitable admin account"
    $Cred | Export-Clixml $CredFile #to use next time
}

# Connect to vCenter
try {
    Connect-VIServer -Server $vCenterName -Credential $Cred -ErrorAction Stop | Out-Null
    Write-Log "Connected to vCenter Server: $vCenterName" 0
}
catch {
    Write-Log "Error connecting to vCenter server: $($_.Exception.Message)" 2
    throw "Error connecting to vCenter server: $($_.Exception.Message)"
}

# Shutdown the VMs in the cluster in a specific order. To do this, assign tags to critical VMs, as follows:
# Tag name = Level1 - shutdown first (e.g. application servers)
# Level2 - shutdown second (e.g. database servers)
# Level3 - shutdown third (e.g. critical infrastructure servers, like Active Directory Domain Controllers).
# You can add more tags if more granularity is required. Use a tag category such as 'ShutDownOrder' to distinguish
# them from other tags. That may be used in the environment
$CriticalVM = @()
1..3 | Foreach-Object {
    $tag = "Level$_"
    Write-Log "Looking for VMs on cluster $ClusterName with a shutdown order tag set to $tag"
    try {
        $Found = $false
        $Cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
        $vmList = $Cluster | Get-VM -Tag $tag -ErrorAction Stop | Where-Object Name -notmatch 'OmniStackVC' | Where-Object PowerState -eq 'PoweredOn'
        $Found = $true
    }
    catch {
        if ($_.Exception.Message -match 'Could not find Tag') {
            Write-Log "No VMs with $tag found"
        }
        Else {
            Write-log "$_.Exception.Message" 2
            throw $_.Exception.Message
        }
    }
    if ($Found) {
        foreach ($vm in $vmList) {
            Write-Log "Found $($vm.name) with shutdown order tag set to $tag"
            
            # Save the VMs we're shutting down now so we can ignore them later. Bad things happen if you try to power off a VM twice.
            $CriticalVM += $($vm.Name)
            
            try {
                if ($Force) {
                    $Response = $vm | Stop-VMGuest -Confirm:$false -ErrorAction Stop
                    Write-Log "$($Response.VM) (tools version:$($response.ToolsVersion)) is shutting down" 
                }
                else {
                    $vm | Stop-VMGuest -Whatif -ErrorAction Stop
                }
            }
            catch {
                if ($_.Exception.Message -match 'Cannot complete operation because VMware Tools is not running') {
                    Write-Log "Cannot shutdown the guest on $($vm.Name) because VMware Tools are not running" 1
                }
                else {
                    Write-Log "Could not shutdown VM $($vm.Name): $_.Exception.Message" 2
                    # Don't throw error. We can at least try to shutdown as many VMs as possible
                }
            }
        }
    }
}

# Now we've shutdown critical VMs (those with tags), shutdown any other VMs left running, ignoring critical VMs and the OVC(s), of course.
Write-Log "Looking for any other powered on VMs on cluster $ClusterName with no/unrecognised tags" 0
try {
    $vmList = $Cluster | 
        Get-VM -ErrorAction Stop | 
        Where-Object Name -NotMatch 'OmniStackVC' | 
        Where-Object Name -NotIn $CriticalVM |
        Where-Object PowerState -eq 'PoweredOn'
}
catch {
    Write-Log "$_.Exception.Message" 2
    throw $_.Exception.Message
}              
foreach ($vm in $vmList) {
    Write-Log "Found $($vm.name) with no shutdown order tag"
    try {
        if ($force) {
            $Response = $vm | Stop-VMGuest -Confirm:$false -ErrorAction Stop
            Write-Log "$($Response.VM) (tools version:$($response.ToolsVersion)) is shutting down" 
        }
        else {
            $vm | Stop-VMGuest -Whatif -ErrorAction Stop
        }
    }
    catch {
        if ($_.Exception.Message -match 'Cannot complete operation because VMware Tools is not running') {
            Write-Log "Cannot shutdown the guest on $($vm.Name) because VMware Tools are not running" 1
        }
        else {
            Write-Log "Could not shutdown VM $($vm.Name): $_.Exception.Message" 2
        }
    }
}

# Connect to the OVC
try {
    Connect-SVT -OVC $OVC -Credential $Cred -IgnoreCertReqs -ErrorAction Stop | Out-Null
    Write-Log "Connected to Omnistack Virtual Controller: $OVC"
}
catch {
    Write-Log "Error connecting to OmniStack Virtual Controller : $($_.Exception.Message)" 2
    throw "Error connecting to OmniStack Virtual Controller : $($_.Exception.Message)"
}

# Wait until all VMs are shutdown (except the OVC)
if ($Force) {
    do {
        Write-Log "Waiting 10 seconds to allow VMs to shutdown"
        Start-Sleep -Seconds 10
        $vmName = $Cluster | Get-VM -ErrorAction Stop | Where-Object Name -NotMatch 'OmniStackVC' | Where-Object PowerState -eq 'PoweredOn'
    } while ($vmName)

    # Shutdown the HPE OmniStack Virtual Controller(s).
    try {
        $Response = Get-SVTHost -ClusterName $ClusterName -ErrorAction Stop | Stop-SVTOVC -ErrorAction Stop #-Verbose
        $Response | ForEach-Object {
            Write-Log "OVC $($_.OVC) has shutdown status of $($_.ShutdownStatus)" 0
        }
    }
    catch {
        Write-Log "Failed to shutdown an OVC : $($_.Exception.Message)"
        throw $_.Exception.Message
    }
}
else {
    Get-SVTHost -ClusterName $ClusterName | Foreach-Object {
        Write-Log "Whatif: Shutdown of $($_.ManagementIP) (on host $($_.HostName)) would be performed now"
    }
}

# Wait until the OVC is shutdown
$VMHost = $Cluster | Get-VMHost
if ($Force) {
    do {
        Write-Log "Waiting 20 seconds to allow OmniStack Controller(s) to shutdown"
        Start-Sleep -Seconds 20
        $vmName = $Cluster | Get-VM -ErrorAction Stop | Where-Object PowerState -eq 'PoweredOn'
    } while ($vmName)

    # Shutdown the host(s)
    try {
        $Response = $VMHost | Set-VMHost -State Maintenance -Confirm:$false -ErrorAction Stop
        $Response | Foreach-object {
            Write-Log "$_ is in connection state of $($_.ConnectionState)" 0
        }
        $Response = $VMHost | Stop-VMHost -Confirm:$false -ErrorAction Stop
        $Response | Foreach-object {
            Write-Log "$_ is in connection state of $($_.ConnectionState) and a power state of $($_.PowerState)" 0
        }
    }
    catch {
        Write-Log "Could not shutdown a least one host : $($_.Exception.Message)" 2
        throw $_.Exception.Message
    }
}
else {
    $VMHost | Set-VMHost -State Maintenance -Whatif
    $VMHost | Stop-VMHost -Whatif
}
Write-Log "Done" 0