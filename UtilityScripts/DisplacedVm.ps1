<#
.SYNOPSIS
    Display SimpliVity virtual machines running on a host other than where their primary storage is located.
.DESCRIPTION
    Simplivity uses virtual machine and host affinity rules in vCenter to ensure VMs run on the same SimpliVity
    node as their primary storage replica. If this not possible, they run where their secondary replica is 
    hosted. In some cases there are situations where this will not be the case. Ususally, this is because there 
    is a conflicting affinity rule which forces the VM to run on another host. In these situations, 
    SimpliVity displays a warning alarm in vCenter stating that "SimpliVity VM Data Access Not Optimized".

    This is expected in situations where you have created affinity rules to make use of SimpliVity compute nodes
    in a SimpliVity cluster, but should otherwise be investigated.

    This command displays SimpliVity virtual machines that are running on hosts other than where their primary
    storage replica is located.
.NOTES
    This command assumes that the HPESimpliVity has been imported and that you have already connected to a 
    SimpliVity Federation using the Connect-Svt command.
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-DisplacedVm.md
.EXAMPLE
    Get-DisplacedVm

    This command displays any VM in the federation that is running on a host other than where their primary 
    replica is hosted.
.EXAMPLE
    Get-DisplacedVm -IgnoreComputeNode

    This command will show displaced VMs, but will ignore VMs currently running on a SimpliVity compute node.
#>

function Get-DisplacedVm {
    [CmdletBinding()]
    param (
        [Switch]$IgnoreComputeNode
    )
    
    begin {
        $Vm = Get-SvtVm
        $Replica = Get-SvtVmReplicaSet
    }
    
    process {
        foreach ($ThisVm in $Vm) {
            $ThisReplica = $Replica | Where-Object VmName -EQ $ThisVm.VmName
            if ($IgnoreComputeNode -and $ThisVm.HostName -eq '*ComputeNode') {
                continue
            }
            if ($ThisVM.Hostname -ne $ThisReplica.Primary) {
                [pscustomobject]@{
                    VmName                   = $ThisVm.HostName
                    Hostname                 = $ThisVm.HostName
                    PrimaryReplicaLocation   = $ThisReplica.Primary
                    SecondaryReplicaLocation = $ThisReplica.Secondary
                }
            }
        } #end foreach
    } #end process
}