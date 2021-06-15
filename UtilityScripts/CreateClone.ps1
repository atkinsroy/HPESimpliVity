###############################################################################################################
# CreateClone.ps1
#
# Description:
#   This script creates clones of virtual machines hosted on HPE SimpliVity storage
#   You can create multiple clones of the same VM or clones of multiple VMs or both.
#
# Requirements:
#   HPESimpliVity V2.0.24 and above
#
# Website:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   VERSION 1.0
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext Services
#
##############################################################################################################

<#
(C) Copyright 2020 Hewlett Packard Enterprise Development LP

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
    Clone one or more Virtual Machines hosted on HPE SimpliVity storage
.DESCRIPTION
     This script will clone a given VM or VMs up to 20 times. It accepts multiple
     SimpliVity Virtual Machine objects and will execute 4 clone operations
     simultaneously, waiting so that only maximum of 4 clones are executing at once.

     Assumes you have previously connected to an OmniStack Virtual Controller (or Management 
     Virtual Appliance) using Connect-Svt. 
.PARAMETER VmName
    Specify one or more VMs to clone
.PARAMETER NumberOfClones
    Specify the number of clones, 1 to 20
.PARAMETER ConsistencyType
    The type of backup used for the clone method, DEFAULT is crash-consistent, VSS is
    application-consistent using VSS and NONE is application-consistent using a snapshot
.EXAMPLE
    PS C:\> .\CreateClone.ps1 -VmName MyVM1

    Creates a new clone with the name of the original VM plus a unique number suffix
.EXAMPLE
    PS C:\> Get-SvtVm -VmName MyVM1 | .\CreateClone.ps1

    Clones the specified VM by passing in the VM object from the pipeline
.EXAMPLE
    PS C:\> $VmList = Get-SvtVm | ? VmName -match 'SQL'
    PS C:\> $VmList | .\CreateClone.ps1

    This clones every VM with 'SQL' in its name, 4 at a time. Use the first command to make sure
    the list of VMs is correct before cloning.
.EXAMPLE
    PS C:\> .\CreateClone -VmName NewVM1 -NumberOfClones 3

    Clone the specified VM three times.
.EXAMPLE
    PS C:\> Get-SvtVm -Datastore Datastore1 | .\CreateClone -NumberOfClones 2

    Clone each VM on the specified datastore twice
.EXAMPLE
    PS C:\> Get-SvtVm | ? VmName -match '^RHEL8-\d{2}$'
    PS C:\> Get-SvtVm | ? VmName -match '^RHEL8-\d{2}$' | .\CreateClone.ps1

    The first command confirms a list of VMs, in this case is matches 'RHEL8-01', 'RHEL8-02' ... 'RHEL8-99'
    The second command creates 2 clones of each - eg. 'RHEL8-01-01', 'RHEL8-01-02', 'RHEL8-02-01', etc.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
#[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true)]
    [System.String]$VmName,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateRange(1, 20)]
    [System.Int32]$NumberOfClones = 1,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateSet('DEFAULT', 'VSS', 'NONE')]
    [System.String]$ConsistencyType = 'NONE'
)

begin {
    $VerbosePreference = 'Continue'
    if ($NumberOfClones -gt 1) {
        Write-Verbose "When cloning the same VM(s) multiple times using -NumberOfClones, clones are performed one at a time"
        $AllowedTask = 1
    }
    else {
        Write-Verbose "When cloning multiple VMs, a maximum of four clone tasks can run at a time"
        $AllowedTask = 4
    }

    # Enumerate all VMs first - confirm clone name is unique
    try {
        $AllVm = Get-SvtVm -ErrorAction Stop -Limit 5000
    }
    catch {
        throw $_.Exception.Message
    }
}
process {
    foreach ($VM in $VmName) {
        [int32]$Suffix = 1
        1..$NumberOfClones | ForEach-Object {
            $OriginVM = ($AllVm | Where-Object VmName -eq $VM).VmName   # Get the real VM name, ensures the right case

            # Note: SimpliVity RESTAPI limits the VmName to 80 characters. (vCenter 6.5+ supports 128)
            if ($OriginVM.Length -gt 77) {
                $OriginVM = $OriginVM.Substring(0, 77)
            }

            # Get a unique VM name for this clone. 
            $TargetFound = $true
            While ($TargetFound) {
                $TargetVM = $OriginVM + '-' + '{0:d2}' -f $Suffix
                if ($TargetVM -in $AllVm.VmName) {
                    Write-Verbose "$TargetVM already exists, incrementing the suffix number"
                }
                else {
                    Write-Verbose "$TargetVM will be created (from $VM)"
                    $TargetFound = $false
                }
                $Suffix += 1
            }

            $Task = New-SvtClone -VmName $VM -CloneName $TargetVM
            [array]$CloneTask += $Task

            # Rules are:
            # 1. If cloning the same VM, we will only do 1 at a time
            # 2. If cloning different VMs, we can only do 4 at a time, as per current recommendations
            while ($true) {
                $ActiveTask = Get-SvtTask -Task $CloneTask |
                Where-Object State -eq "IN_PROGRESS" |
                Measure-Object |
                Select-Object -ExpandProperty Count
                Write-Verbose "There are $ActiveTask active cloning tasks"

                if ($ActiveTask -ge $AllowedTask) {
                    Write-Verbose "Sleeping 5 seconds, only cloning $AllowedTask at a time"
                    Start-Sleep -Seconds 5
                }
                else {
                    break
                }
            }
        } #end NumberOfClones 
    } #end foreach VM
}
end {
    $Global:SvtTask = $CloneTask
    Get-SvtTask
}
