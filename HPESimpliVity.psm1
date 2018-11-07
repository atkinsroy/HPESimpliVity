##############################################################################
# HPESimplivity.psm1
#
# Description:
#   This module provides management cmdlets for HPE Simplivity via the 
#   REST API. This module has been written and tested with version 3.7.5.
# 
# Download:
#   https://github.com/atkinsroy/POSH-HPESimpliVity
#
#   VERSION 1.0
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext
#
# (C) Copyright 2018 Hewlett Packard Enterprise Development LP 
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

# Helper function used by all cmdlets to connect to the OVC.
function Connect-SVTOVC {
    [cmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC
    )

    # Create an XML containing credentials. The password is stored as a secure-string.
    $CurrentPath = Split-Path -Parent $PSCommandPath
    $Credfile = "$CurrentPath\SVTcred.xml"
    if (-not (Test-Path $Credfile)) {
        Get-Credential -Message "Enter credentials with authorisation to login to your OmniStack Virtual Controller (e.g. administrator@vsphere.local)" | Export-Clixml $Credfile
    }
    $Credential = Import-Clixml $Credfile

    # Allow untrusted SSL certificates with HTTPS connections and enable TLS 1.2.
    # NOTE: You don't need any of this with PowerShell 6.0; it supports TLS1.2 natively and allows 
    # certificate bypass using Invoke-Method -SkipCertificateCheck
    $Source = @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@

    #Ignore Self Signed Certificates and set TLS
    Try {
        Add-Type -TypeDefinition $Source
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    Catch {
        $_.Exception.ToString()
    }

    # Authenticate with SimpliVity OmniStack Virtual Controller and retrieve an access token
    $BaseURL = "https://" + $OVC + "/api/oauth/token"
    $Header = @{"Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes("simplivity:"))}
    $Body = @{
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
        grant_type = "password"
    }
    $Token = Invoke-RestMethod -Uri $BaseURL -Headers $Header -Body $Body -Method Post | Select-object -ExpandProperty access_token

    # Create Auth Header and return it to the calling function
    $SVTSessionHeader = @{"Authorization" = "Bearer " + $Token}
    $SVTSessionHeader
}

<#
.SYNOPSIS
    Display HPE SimpliVity backup information 
.DESCRIPTION
    Show backup information from the SimpliVity Federation. By default SimpliVity backups
    from the last 24 hours are shown, but this can be overridden by specifying an Hour parameter.
    Further filtering of the REST API call can be done by specifying one or more other parameters
.PARAMETER OVC
    Specify the OmniStack Virtual Controller to connect to. This is a mandatory parameter.
.PARAMETER VM
    Show backups for the specified virtual machine only.
.PARAMETER Datastore
    Show backups from the specified datastore only.
.PARAMETER Cluster
    Show backups from the specfied SimpliVity Cluster only.
.PARAMETER Hour
    The number of hours preceeding to report on. By default, only the last 24 hours are shown.
.EXAMPLE
    Get-SVTBackup -OVC <IP>

    Shows the last 24 hours worth of backups from the Simplivity Federation.
.EXAMPLE
    Get-SVTBackup -OVC <IP> -Hour 48 | Select-Object VM, DataStore, SentMB, UniqueSizeMB | Format-Table -Autosize

    Shows the last 48 hours worth of backups, selecting specific properties to display
.EXAMPLE
    Get-SVTBackup -OVC <IP> -VM MyVM -Cluster MyCluster

    Shows backups in the last 24 hours for the specified VM and cluster only.
.OUTPUTS
    Custom Powershell object containing properties from the REST GET /backups operation
.NOTES
    Tested with SVT 3.7.5
#>
function Get-SVTBackup {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC,

        [string]$VM,

        [string]$Datastore,

        [string]$Cluster,

        [string]$Hour = 24
    )

    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    # Get date for specified hour
    $StartDate = (get-date).AddHours(-$Hour).ToUniversalTime()
    $CreatedAfter = "$(get-date $StartDate -format s)Z"

    # Get Backups in Federation
    $uri = "https://" + $OVC + "/api/backups?show_optional_fields=false&created_after=" + $CreatedAfter
    if ($VM) {
        $uri += "&virtual_machine_name=" + $VM
    }
    if ($DataStore) {
        $uri += "&datastore_name=" + $DataStore
    }
    If ($Cluster) {
        $uri += "&omnistack_cluster_name=" + $Cluster
    }
    $uri += "&case=insensitive"

    $backup = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get
    $backup.backups | Foreach-object {
        if ($_.unique_size_timestamp -as [DateTime]) {
            $UniqueSizeDate = Get-Date -Date $_.unique_size_timestamp
        }
        else {
            $UniqueSizeDate = $null
        }
        if ($_.expiration_time -as [Datetime]) {
            $ExpirationDate = Get-Date -Date $_.expiration_time
        }
        else {
            $ExpirationDate = $null
        }
        $SVTbackup = [PSCustomObject] @{
            VM               = $_.virtual_machine_name
            CreateDate       = Get-Date -Date $_.created_at
            ConsistencyType  = $_.consistency_type
            Type             = $_.type
            DataStore        = $_.datastore_name
            AppConsistent    = $_.application_consistent
            VMID             = $_.virtual_machine_id
            ParentID         = $_.compute_cluster_parent_hypervisor_object_id
            BackupID         = $_.id
            State            = $_.state
            ClusterID        = $_.omnistack_cluster_id
            VMType           = $_.virtual_machine_type
            SentCompleteDate = $_.sent_completion_time 
            UniqueSizeMB     = "{0:n0}" -f ($_.unique_size_bytes / 1mb) 
            ExpiryDate       = $ExpirationDate
            UniqueSizeDate   = $UniqueSizeDate
            Cluster          = $_.omnistack_cluster_name
            SentMB           = "{0:n0}" -f ($_.sent / 1mb)
            SizeGB           = "{0:n2}" -f ($_.size / 1gb)
            VMState          = $_.virtual_machine_state
            Name             = $_.name
            DatastoreID      = $_.datastore_id
            DataCenter       = $_.compute_cluster_parent_name
            Hypervisor       = $_.hypervisor_type
            SentDuration     = $_.sent_duration
        }
        $SVTbackup.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.Backup')
        $SVTBackup
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity datastore information 
.DESCRIPTION
    Shows datastore information from the SimpliVity Federation
.EXAMPLE
    Get-SVTDataStore -OVC <IP>

    Shows all datastores in the Federation
.EXAMPLE
    Get-SVTDataStore -OVC <IP> -Datastore MyDS | Export-CSV Datastore.csv

    Exports the specified datastore information to a CSV
.EXAMPLE
    Get-SVTDataStore -OVC <IP> | Select-Object Name, SizeGB, Policy
.OUTPUTS
    custom Powershell object containing proprties from the REST GET /datastores operation
.NOTES
	Tested with SVT 3.7.5
#>
function Get-SVTDatastore {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC,

        [String]$Datastore
    )

    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    #Get OmniStack Datastores in Federation
    if ($Datastore) {
        $uri = "https://" + $OVC + "/api/datastores?show_optional_fields=false&name=" + $Datastore + "&case=insensitive"
    }
    else {
        $uri = "https://" + $OVC + "/api/datastores?show_optional_fields=false"
    }
    $datastoreList = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get

    $datastoreList.datastores | ForEach-Object {
        $SVTdatastore = [PSCustomObject] @{
            PolicyID       = $_.policy_id
            MountDirectory = $_.mount_directory
            CreateDate     = Get-Date -Date $_.created_at
            Policy         = $_.policy_name
            Cluster        = $_.omnistack_cluster_name
            Shares         = $_.shares
            Deleted        = $_.deleted
            HyperVisorID   = $_.hypervisor_object_id
            SizeGB         = "{0:n0}" -f ($_.size / 1gb)
            Name           = $_.name
            DataCenterID   = $_.compute_cluster_parent_hypervisor_object_id
            DataCenter     = $_.compute_cluster_parent_name
            Hypervisor     = $_.hypervisor_type
            DataStoreID    = $_.id
            ClusterID      = $_.omnistack_cluster_id
            VCenterIP      = $_.hypervisor_management_system
            VCenter        = $_.hypervisor_management_system_name
        }
        $SVTdatastore.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.DataStore')
        $SVTdatastore
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity host information 
.DESCRIPTION
    Shows host information from the SimpliVity Federation.
.EXAMPLE
    Get-SVTDataHost -OVC <IP>

    Shows all hosts in the Federation
.EXAMPLE
    Get-SVTHost -OVC <IP> -Cluster MyCluster

    Shows hosts in specified Datacenter
.EXAMPLE
    Get-SVTHost -OVC <IP> | Where-Object DataCenter -eq MyDC

    Shows hosts in specified Datacenter
.OUTPUTS
    custom Powershell object containing proprties from the REST GET /hosts operation
.NOTES
	Tested with SVT 3.7.5
#>
function Get-SVTHost {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC,

        [String]$Cluster
    )

    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    #Get OmniStack Hosts in Federation
    if ($Cluster) {
        $uri = "https://" + $OVC + "/api/hosts?show_optional_fields=false&compute_cluster_name=" + $Cluster + "&case=insensitive"
    }
    else {
        $uri = "https://" + $OVC + "/api/hosts?show_optional_fields=false"
    }

    $HostList = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get
    $HostList.hosts | Foreach-Object {
        $SVThost = [PSCustomObject] @{
            PolicyEnabled         = $_.policy_enabled
            ClusterID             = $_.compute_cluster_hypervisor_object_id
            StorageMask           = $_.storage_mask
            PotentialFeatureLevel = $_.potential_feature_level
            Type                  = $_.type
            CurrentFeatureLevel   = $_.current_feature_level
            HypervisorID          = $_.hypervisor_object_id
            Cluster               = $_.compute_cluster_name
            ManagementIP          = $_.management_ip
            FederationIP          = $_.federation_ip
            OVC                   = $_.virtual_controller_name
            FederationMask        = $_.federation_mask
            Model                 = $_.model
            DataCenterID          = $_.compute_cluster_parent_hypervisor_object_id
            ID                    = $_.id
            StoreageMTU           = $_.storage_mtu
            State                 = $_.state
            UpgradeState          = $_.upgrade_state
            FederationMTU         = $_.federation_mtu
            CanRollback           = $_.can_rollback
            StorageIP             = $_.storage_ip
            ManagementMTU         = $_.management_mtu
            Version               = $_.version
            Name                  = $_.name
            DataCenter            = $_.compute_cluster_parent_name
            VCenterIP             = $_.hypervisor_management_system
            ManagementMask        = $_.management_mask
            VCenter               = $_.hypervisor_management_system_name
        }
        $SVThost.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.Host')
        $SVThost
    }
}


<#
.SYNOPSIS
    Display HPE SimpliVity cluster information 
.DESCRIPTION
    Shows cluster information from the SimpliVity Federation.
.EXAMPLE
    Get-SVTDataCluster -OVC <IP>

    Shows all clusters in the Federation
.OUTPUTS
    custom Powershell object containing proprties from the REST GET /omnistack_clusters operation
.NOTES
	Tested with SVT 3.7.5
#>
function Get-SVTCluster {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC
    )

    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    #Get OmniStack Clusters in Federation
    $uri = "https://" + $OVC + "/api/omnistack_clusters?show_optional_fields=false"
    
    $ClusterList = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get
    $ClusterList.omnistack_clusters | ForEach-Object {
        $SVTcluster = [PSCustomObject] @{
            DataCenter       = $_.hypervisor_object_parent_name
            ArbiterConnected = $_.arbiter_connected
            DataCenterID     = $_.hypervisor_object_parent_id
            Type             = $_.type
            Version          = $_.version
            ClusterID        = $_.hypervisor_object_id
            Members          = $_.members
            Name             = $_.name
            ArbiterIP        = $_.arbiter_address
            HypervisorType   = $_.hypervisor_type
            ID               = $_.id
            VCenterIP        = $_.hypervisor_management_system
            VCenter          = $_.hypervisor_management_system_name
        }
        $SVTcluster.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.Cluster')
        $SVTcluster
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity backup policy rule information 
.DESCRIPTION
    Shows the rules of all backup policies from the SimpliVity Federation.
.EXAMPLE
    Get-SVTPolicy -OVC <IP>

    Shows all backup policy rules.
.EXAMPLE
    Get-SVTPolicy -OVC <IP> | Where Policy -eq MyPolicy

    Show the rules of the specified policy
.OUTPUTS
    custom Powershell object containing proprties from the REST GET /policies operation
.NOTES
	Tested with SVT 3.7.5
#>
function Get-SVTPolicy {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC
    )
 
    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    #Get OmniStack Policies in Federation
    $uri = "https://" + $OVC + "/api/policies?show_optional_fields=false"
    
    $PolicyList = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get
    $PolicyList.policies | ForEach-Object {
        $Policy = $_.name
        $_.rules | ForEach-Object {
            $SVTpolicy = [PSCustomObject] @{
                Policy                = $Policy
                DestinationID         = $_.destination_id
                EndTime               = $_.end_time
                Destination           = $_.destination_name
                ConsistencyType       = $_.consistency_type
                FrequencyHour         = $_.frequency / 60
                ApplicationConsistent = $_.application_consistent
                RuleNumber            = $_.number
                StartTime             = $_.start_time
                MaxBackup             = $_.max_backups
                Day                   = $_.days
                ID                    = $_.id
                Retention             = $_.retention
            }
            $SVTpolicy.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.Policy')
            $SVTpolicy
        }
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity virtual machine information 
.DESCRIPTION
    Shows virtual machine information from the SimpliVity Federation.
.EXAMPLE
    Get-SVTVM -OVC <IP>

    Shows all virtual machines in the Federation
.EXAMPLE
    Get-SVTVM -OVC <IP> -VM MyVM | Out-GridView -Passthru | Export-CSV FilteredVMList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports 
    this to a CSV
.EXAMPLE
    Get-SVTVM | Select-Object Name, SizeGB, Policy
.OUTPUTS
    custom Powershell object containing proprties from the REST GET /virtual_machine operation
.NOTES
	Tested with SVT 3.7.5
#>
function Get-SVTVM {
    [cmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$OVC,

        [String]$VM
    )

    # Connect to OVC
    $Header = Connect-SVTOVC -OVC $OVC

    #Get OmniStack VMs in Federation
    if ($VM) {
        $uri = "https://" + $OVC + "/api/virtual_machines?show_optional_fields=false&name=" + $VM + "&case=insensitive"
    }
    else {
        $uri = "https://" + $OVC + "/api/virtual_machines?show_optional_fields=false"
    }
    $VMlist = Invoke-RestMethod -Uri $uri -Headers $Header -Method Get

    $VMlist.virtual_machines | Foreach-Object {
        if ($_.deleted_at -as [DateTime]) {
            $DeletedDate = Get-Date -Date $_.deleted_at
        }
        else {
            $DeletedDate = $null
        }

        $SVTvm = [PSCustomObject] @{
            PolicyID         = $_.policy_id
            CreateDate       = Get-date -Date $_.created_at
            Policy           = $_.policy_name
            DataStore        = $_.datastore_name
            Cluster          = $_.omnistack_cluster_name
            DeletedDate      = $DeletedDate
            AppAwareVMStatus = $_.app_aware_vm_status
            HostID           = $_.host_id
            HypervisorID     = $_.hypervisor_object_id
            Name             = $_.name
            DatastoreID      = $_.datastore_id
            ReplicaSet       = $_.replica_set
            DataCenterID     = $_.compute_cluster_parent_hypervisor_object_id
            DataCenter       = $_.compute_cluster_parent_name
            Hypervisor       = $_.hypervisor_type
            ID               = $_.id
            State            = $_.state
            ClusterID        = $_.omnistack_cluster_id
            VcenterIP        = $_.hypervisor_management_system
            Vcenter          = $_.hypervisor_management_system_name
        }
        $SVTvm.PSObject.TypeNames.Insert(0,'HPE.SimpliVity.VM')
        $SVTvm
    }
}