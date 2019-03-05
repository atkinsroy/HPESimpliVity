##############################################################################
# HPESimplivity.psm1
#
# Description:
#   This module provides management cmdlets for HPE Simplivity via the 
#   REST API. This module has been written and tested with version 3.7.7.
# 
# Download:
#   https://github.com/atkinsroy/POSH-HPESimpliVity
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

# Helper function for Invoke-RestMethod to handle errors.
function Invoke-SVTRestMethod {
    param (
        [parameter(Mandatory=$true,Position=0)]
        [System.Object]$Uri,
        
        [parameter(Mandatory=$true,Position=1)]
        [System.Collections.IDictionary]$Header,
        
        [parameter(Mandatory=$true,Position=2)]
        [ValidateSet('get','post','delete')]
        [System.String]$Method,

        [parameter(Mandatory=$false,Position=3)]
        [System.Object]$Body
    )
    try {
        if ($Body) {
            Invoke-RestMethod -Uri $Uri -Headers $Header -Body $Body -Method $Method -ErrorAction Stop
        }
        else {
            Invoke-RestMethod -Uri $Uri -Headers $Header -Method $Method -ErrorAction Stop
        }
    }

    catch [System.Management.Automation.RuntimeException] {
        throw "It looks as though your session has timed out. Use Connect-SVT to reconnect: $($_.Exception.Message)"
        return
    }
    catch [System.UriFormatException] {
        throw "It looks as though you have not connected to the OVC or you've specified an invalid IP address to connect. Use Connect-SVT to connect first and confirm the IP address used: $($_.Exception.Message)"
        return
    }
    catch {
        # Catch any other error
        throw "An unexpected error has occured: $($_.Exception.Message)"
        return
    }
}

<#
.SYNOPSIS 
	Obtain an authentication token from a HPE SimpliVity OmniStack Virtual Controller (OVC)
.DESCRIPTION
	To access the SimpliVity RESTAPI, you need to request an authentication token by issuing a request 
    using the OAuth authentication method. Once obtained, you can pass the resulting access_token via the 
    HTTP header using an Authorization Bearer token.

    The access token is stored in a Global Variable accessible to all cmdlets in the PowerShell session.
    Note that the access token times out after 10 minutes of inactivty. If this happens, simply run this
    cmdlet again.
.PARAMETER OVC
    Required. The IP address of an OVC. This is the management IP address
.PARAMETER IgnoreCertReqs
    Allow untrusted self-signed SSL certificates with HTTPS connections and enable TLS 1.2.
    NOTE: You don't need this with PowerShell 6.0; it supports TLS1.2 natively and allows certificate bypass 
    using Invoke-Method -SkipCertificateCheck
.PARAMETER Username 
    The specified Username must have admin rights to the SimpliVity Federation. Typically this will be an Active Directory account,
    provisioned in VMware vCenter or Microsoft System Center Virtual Machine Manager, depending on the hypervisor.
.PARAMETER password
    The password for the specified user account
.PARAMETER OVCcred
	User generated credential as System.Management.Automation.PSCredential. This can also be imported from a file
.INPUTS
    [System.String]
.OUTPUTS
	[System.Management.Automation.PSCustomObject]
.EXAMPLE
    Connect-SVT -OVC <IP Address of OVC> -IgnoreCertReqs

    This will prompt you for credentials
.EXAMPLE
    Connect-SVT -OVC <IP Address of OVC> -OVCusername <username@domain> -OVCpassword <password> -IgnoreCertReqs
.EXAMPLE
    Connect-SVT -OVC <IP Address of OVC>  -OVCcred <User generated Secure credentials> -IgnoreCertReqs

    Create the credential first, then pass it as OVCcred parameter, for example
    PS> $MyCredentials = Get-Credential -Message "Enter Credentials"
    PS> Connect-SVT -OVC 10.10.57.60 -OVCcred $MyCredentials
.EXAMPLE
    Connect-SVT -OVC <IP Address of OVC> -OVCcred <Secure credentials from a file>

	This method is useful in non-iteractive sessions. To generate and use a credential file, enter the 
    following commands:
    PS> $CredFile = "$((Get-Location).Path)\OVCcred.XML"
	PS> Get-Credential -Credential"<username@domain"| Export-CLIXML $CredFile

    # Then use the credentials from the file:
    PS> Connect-SVT -OVC 10.10.57.60 -OVCcred $(Import-CLIXML $CredFile)

.NOTES
    Tested with HPE OmniStack 3.7.7
#>
function Connect-SVT {
	[CmdletBinding()][OutputType('System.Management.Automation.PSObject')]
	param(
		[parameter(Mandatory=$true)]
		[String]$OVC,
		
		[switch]$IgnoreCertReqs,
 
        [String]$Username,

        [String]$Password,
		
        [System.Management.Automation.PSCredential]$Credential
	)

	if ($IgnoreCertReqs.IsPresent) {	
		if ( -not ("TrustAllCertsPolicy" -as [type])) {
            $Source = @"
                using System.Net;
                using System.Security.Cryptography.X509Certificates;
                public class TrustAllCertsPolicy : ICertificatePolicy
                {
                    public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem)
                    {
                        return true;
                    }
                }
"@
        Add-Type -TypeDefinition $Source
        }		

		[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
		[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		$SignedCertificates = $false
	}
    else {
		$SignedCertificates = $true 
	}

	# Confirm the OVC given is a valid IP address
	$IsValid = ($OVC -as [Net.IPAddress]) -as [Bool]
	If ( $IsValid -eq $false ) {
		Write-Error "$OVC is an invalid IP Address"
		return
	}

	# Three ways to authenticate -  via a credential object, passed as parameters or securely prompt for credential, in that order
	if ($Credential) {
		$OVCcred = $Credential
	} 
    elseif (($Username) -and ($Password)) {	
		$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
		$OVCcred = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
	} 
    else {
        # Default to prompting securely for credentials
	    $OVCcred = Get-Credential -Message "Enter credentials with authorisation to login to your OmniStack Virtual Controller (e.g. administrator@vsphere.local)"
    }
	

	$Uri = 'https://' + $OVC + '/api/oauth/token'
	
    # Case is important here with property names
    $Header = @{'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes('simplivity:'))
                'Accept' = 'application/json'}
	
    $Body = @{'username' = $OVCcred.Username
            'password'   = $OVCcred.GetNetworkCredential().Password
            'grant_type' = 'password'}

	try {
		$Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
	} 
    catch {
		throw $_.Exception.Message
	}
 
	$Global:SVTConnection = [pscustomobject]@{
		OVC = "https://$OVC"
		OVCcred = $OVCcred
		Token = $Response.access_token
		UpdateTime = $Response.updated_at
		Expiration = $Response.expires_in
		SignedCertificates = $SignedCertificates
	}
    # Return connection object to the pipeline. Used by all other cmdlets.
	$Global:SVTConnection
}

<#
.SYNOPSIS
    Display HPE SimpliVity backup information 
.DESCRIPTION
    Show backup information from the HPE SimpliVity Federation. By default SimpliVity backups
    from the last 24 hours are shown, but this can be overridden by specifying an Hour parameter.
    Further filtering of the REST API call can be done by specifying one or more additional parameters
.PARAMETER Hour
    The number of hours preceeding to report on. By default, only the last 24 hours are shown.
.PARAMETER BackupName
    Show specified backup
.PARAMETER VMName
    Show backups for the specified virtual machine only.
.PARAMETER DataStoreName
    Show backups from the specified datastore only.
.PARAMETER ClusterName
    Show backups from the specified HPE SimpliVity Cluster only.

.EXAMPLE
    Get-SVTBackup

    Shows the last 24 hours worth of backups from the Simplivity Federation.
.EXAMPLE
    Get-SVTBackup -Hour 48 | Select-Object VM, DataStore, SentMB, UniqueSizeMB | Format-Table -Autosize

    Shows the last 48 hours worth of backups, selecting specific properties to display
.EXAMPLE
    Get-SVTBackup -VMName MyVM

    Shows backups in the last 24 hours for the specified VM only.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Backup
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVTBackup {
    [cmdletBinding()]
    Param (
        [string]$Hour = 24,

        [string]$BackupName,

        [string]$VMName,

        [string]$DatastoreName,

        [string]$ClusterName    
    )
   
    # Connect to OVC via the token
    $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}
    
    # Get Backups in Federation
    $Uri = $($Global:SVTConnection.OVC) + "/api/backups?show_optional_fields=false"
    
    # Show backups from specified backup name. If no backup name is specified, show the last 24 hours by default
    if ($BackupName) {
        $BackupName = "$BackupName*" 
        $Uri += "&name=" + ($BackupName -replace "\+","%2B")
    }
    else {
        # Get date for specified hour
        $StartDate = (get-date).AddHours(-$Hour).ToUniversalTime()
        $CreatedAfter = "$(get-date $StartDate -format s)Z"
        $Uri += "&created_after=" + $CreatedAfter
        Write-Verbose "Displaying Backups from the last $Hour hours,(i.e. created after $CreatedAfter)"
    }

    if ($VMName) {
        $Uri += "&virtual_machine_name=" + $VMName
    }
    if ($DataStoreName) {
        $Uri += "&datastore_name=" + $DataStoreName
    }
    If ($ClusterName) {
        $Uri += "&omnistack_cluster_name=" + $ClusterName
    }
    $Uri += "&case=insensitive"

    # Get backups
    try {
        $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.backups | Foreach-object {
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
        $CustomObject = [PSCustomObject] @{
            PSTypeName       = 'HPE.SimpliVity.Backup'
            VMName           = $_.virtual_machine_name
            CreateDate       = Get-Date -Date $_.created_at
            ConsistencyType  = $_.consistency_type
            BackupType       = $_.type
            DataStoreName    = $_.datastore_name
            AppConsistent    = $_.application_consistent
            VMID             = $_.virtual_machine_id
            ParentID         = $_.compute_cluster_parent_hypervisor_object_id
            BackupID         = $_.id
            BackupState      = $_.state
            ClusterID        = $_.omnistack_cluster_id
            VMType           = $_.virtual_machine_type
            SentCompleteDate = $_.sent_completion_time 
            UniqueSizeMB     = "{0:n0}" -f ($_.unique_size_bytes / 1mb) 
            ExpiryDate       = $ExpirationDate
            UniqueSizeDate   = $UniqueSizeDate
            ClusterName      = $_.omnistack_cluster_name
            SentMB           = "{0:n0}" -f ($_.sent / 1mb)
            SizeGB           = "{0:n2}" -f ($_.size / 1gb)
            VMState          = $_.virtual_machine_state
            BackupName       = $_.name
            DatastoreID      = $_.datastore_id
            DataCenterName   = $_.compute_cluster_parent_name
            HypervisorType   = $_.hypervisor_type
            SentDuration     = $_.sent_duration
        }
        If (Get-TypeData -TypeName 'HPE.SimpliVity.Backup') {
            Remove-TypeData -TypeName 'HPE.SimpliVity.Backup'
        }
        # PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
        Update-TypeData -TypeName 'HPE.SimpliVity.Backup' -DefaultDisplayPropertySet BackupName, VMName, CreateDate, SizeGB
        $CustomObject
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity datastore information 
.DESCRIPTION
    Shows datastore information from the SimpliVity Federation
.EXAMPLE
    Get-SVTDataStore

    Shows all datastores in the Federation
.EXAMPLE
    Get-SVTDataStore -DatastoreName MyDS | Export-CSV Datastore.csv

    Exports the specified datastore information to a CSV
.EXAMPLE
    Get-SVTDataStore | Select-Object Name, SizeGB, Policy
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.DataStore
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTDatastore {
    [cmdletBinding()]
    Param (
        [String]$DatastoreName
    )

    # Connect to OVC via the token
    $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}
   
    #Get OmniStack Datastores in Federation
    $Uri = $($Global:SVTConnection.OVC) + '/api/datastores?show_optional_fields=false'

    if ($DatastoreName) {
        $Uri += '&name=' + $DatastoreName   
    }
    $Uri += '&case=insensitive'
    
    try {
        $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.datastores | ForEach-Object {
        $CustomObject = [PSCustomObject] @{
            PSTypeName     = 'HPE.SimpliVity.DataStore'
            PolicyID       = $_.policy_id
            MountDirectory = $_.mount_directory
            CreateDate     = Get-Date -Date $_.created_at
            PolicyName     = $_.policy_name
            ClusterName    = $_.omnistack_cluster_name
            Shares         = $_.shares
            Deleted        = $_.deleted
            HyperVisorID   = $_.hypervisor_object_id
            SizeGB         = "{0:n0}" -f ($_.size / 1gb)
            DataStoreName  = $_.name
            DataCenterID   = $_.compute_cluster_parent_hypervisor_object_id
            DataCenterName = $_.compute_cluster_parent_name
            HypervisorType = $_.hypervisor_type
            DataStoreID    = $_.id
            ClusterID      = $_.omnistack_cluster_id
            VCenterIP      = $_.hypervisor_management_system
            VCenterName    = $_.hypervisor_management_system_name
        }
        If (Get-TypeData -TypeName 'HPE.SimpliVity.DataStore') {
            Remove-TypeData -TypeName 'HPE.SimpliVity.DataStore'
        }
        # PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
        Update-TypeData -TypeName 'HPE.SimpliVity.DataStore' -DefaultDisplayPropertySet DataStoreName, DataCenterName, ClusterName, SizeGB
        $CustomObject
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity host information 
.DESCRIPTION
    Shows host information from the SimpliVity Federation.
.PARAMETER HostName
    Show the specified host only
.PARAMTER ClusterName
    Show hosts from the the specified SimpliVity cluster only
.EXAMPLE
    Get-SVTHost

    Shows all hosts in the Federation
.EXAMPLE
    Get-SVTHost -HostName MyHost

    Shows the specified host
.EXAMPLE
    Get-SVTHost -ClusterName MyCluster

    Shows hosts in specified HPE SimpliVity cluster
.EXAMPLE
    Get-SVTHost | Where-Object DataCenter -eq MyDC | Format-List *

    Shows all properties for all hosts in specified Datacenter
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Host
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTHost {
    [cmdletBinding()]
    Param (
        [string]$HostName,

        [String]$ClusterName
    )

    # Connect to OVC via the token
    $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}
    
    #Get OmniStack Hosts in Federation
    $Uri = $($Global:SVTConnection.OVC) + "/api/hosts?show_optional_fields=False"

    if ($HostName) {
        $Uri += "&name=" + $HostName
    }
    if ($ClusterName) {
        $Uri += "&compute_cluster_name=" + $ClusterName
    }
    $Uri += "&case=insensitive"
    
    # get hosts
    try {
        $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.hosts | Foreach-Object {
        $CustomObject = [PSCustomObject] @{
            PSTypeName            = 'HPE.SimpliVity.Host'
            PolicyEnabled         = $_.policy_enabled
            ClusterID             = $_.compute_cluster_hypervisor_object_id
            StorageMask           = $_.storage_mask
            PotentialFeatureLevel = $_.potential_feature_level
            Type                  = $_.type
            CurrentFeatureLevel   = $_.current_feature_level
            HypervisorID          = $_.hypervisor_object_id
            ClusterName           = $_.compute_cluster_name
            ManagementIP          = $_.management_ip
            FederationIP          = $_.federation_ip
            OVCName               = $_.virtual_controller_name
            FederationMask        = $_.federation_mask
            Model                 = $_.model
            DataCenterID          = $_.compute_cluster_parent_hypervisor_object_id
            HostID                = $_.id
            StoreageMTU           = $_.storage_mtu
            State                 = $_.state
            UpgradeState          = $_.upgrade_state
            FederationMTU         = $_.federation_mtu
            CanRollback           = $_.can_rollback
            StorageIP             = $_.storage_ip
            ManagementMTU         = $_.management_mtu
            Version               = $_.version
            HostName              = $_.name
            DataCenter            = $_.compute_cluster_parent_name
            VCenterIP             = $_.hypervisor_management_system
            ManagementMask        = $_.management_mask
            VCenter               = $_.hypervisor_management_system_name
        }
        If (Get-TypeData -TypeName 'HPE.SimpliVity.Host') {
            Remove-TypeData -TypeName 'HPE.SimpliVity.Host'
        }
        #PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
        Update-TypeData -TypeName 'HPE.SimpliVity.Host' -DefaultDisplayPropertySet HostName, DataCenter, ClusterName, Version
        $CustomObject
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity cluster information 
.DESCRIPTION
    Shows cluster information from the SimpliVity Federation.
.EXAMPLE
    Get-SVTDataCluster

    Shows all clusters in the Federation
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Cluster
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTCluster {
    [cmdletBinding()]
    Param (
        [string]$ClusterName
    )

    # Connect to OVC via the token
    $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}

    #Get OmniStack Clusters in Federation
    $Uri = $($Global:SVTConnection.OVC) + "/api/omnistack_clusters?show_optional_fields=false"

    If ($ClusterName) {
        $Uri += "&name=" + $ClusterName
    }
    $Uri += "&case=insensitive"
    
    # Get SimpliVity Clusters
    try {
        $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.omnistack_clusters | ForEach-Object {
        $CustomObject = [PSCustomObject] @{
            PSTypeName          = 'HPE.SimpliVity.Cluster'
            DataCenterName      = $_.hypervisor_object_parent_name
            ArbiterConnected    = $_.arbiter_connected
            DataCenterID        = $_.hypervisor_object_parent_id
            Type                = $_.type
            Version             = $_.version
            HypervisorClusterID = $_.hypervisor_object_id
            Members             = $_.members
            ClusterName         = $_.name
            ArbiterIP           = $_.arbiter_address
            HypervisorType      = $_.hypervisor_type
            ClusterID           = $_.id
            HypervisorIP        = $_.hypervisor_management_system
            HypervisorName      = $_.hypervisor_management_system_name
        }
        If (Get-TypeData -TypeName 'HPE.SimpliVity.Cluster') {
            Remove-TypeData -TypeName 'HPE.SimpliVity.Cluster'
        }
        #PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
        Update-TypeData -TypeName 'HPE.SimpliVity.Cluster' -DefaultDisplayPropertySet ClusterName, DataCenterName, ArbiterIP, ArbiterConnected
        $CustomObject
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity backup policy rule information 
.DESCRIPTION
    Shows the rules of all backup policies from the SimpliVity Federation.
.EXAMPLE
    Get-SVTPolicy

    Shows all backup policy rules
.EXAMPLE
    Get-SVtPolicy -PolicyName Silver

    Shows the specified backup policy
.EXAMPLE
    Get-SVTPolicy | Where Retention -eq 28

    Show
.INPUTS
    System.String 
.OUTPUTS
    HPE.SimpliVity.Policy
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTPolicy {
    [cmdletBinding()]
    Param (
        [string]$PolicyName
    )
 
    # Connect to OVC via the token
    $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}

    #Get OmniStack Backup Policies in Federation
    $Uri = $($Global:SVTConnection.OVC) + '/api/policies?show_optional_fields=false'

    if ($PolicyName) {
        $Uri += '&name=' + $PolicyName
    }
    $Uri += '&case=insensitive'
    
    # SimpliVity policies
    try {
        $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.policies | ForEach-Object {
        $Policy = $_.name
        $_.rules | ForEach-Object {
            $CustomObject = [PSCustomObject] @{
                PSTypeName            = 'HPE.SimpliVity.Policy'
                PolicyName            = $Policy
                DestinationID         = $_.destination_id
                EndTime               = $_.end_time
                DestinationName       = $_.destination_name
                ConsistencyType       = $_.consistency_type
                FrequencyHour         = $_.frequency / 60
                ApplicationConsistent = $_.application_consistent
                RuleNumber            = $_.number
                StartTime             = $_.start_time
                MaxBackup             = $_.max_backups
                Day                   = $_.days
                PolicyID              = $_.id
                RetentionMin          = $_.retention
            }
            If (Get-TypeData -TypeName 'HPE.SimpliVity.Policy') {
                Remove-TypeData -TypeName 'HPE.SimpliVity.Policy'
            }
            #PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
            Update-TypeData -TypeName 'HPE.SimpliVity.Policy' -DefaultDisplayPropertySet PolicyName, DestinationName , StartTime, RetentionMin
            $CustomObject
        }
    }
}

<#
.SYNOPSIS
    Get VMs running on HPE SimpliVity hosts/storage
.DESCRIPTION
     Show the Virtual machines that are running on HPE SimpliVity hosts.
.EXAMPLE
    Get-SVTVM

    Shows all virtual machines in the Federation
.EXAMPLE
    Get-SVTVM -VMName MyVM | Out-GridView -Passthru | Export-CSV FilteredVMList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports 
    this to a CSV
.EXAMPLE
    Get-SVTVM | Select-Object Name, SizeGB, Policy
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.VirtualMachine
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTVM {
    [cmdletBinding()]
    Param (
        [String]$VMName,

        [Parameter(Mandatory=$false, Position=1, ValueFromPipeline=$true, ValueFromPipelinebyPropertyName=$true)]
        [String[]]$HostID
    )

    begin {
        # Connect to OVC via the token
        $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	            'Accept' = 'application/json'}
    }
 
    process {
        #Get OmniStack VMs in Federation
        $uri = $($Global:SVTConnection.OVC) + "/api/virtual_machines?show_optional_fields=false"
        if ($VMName) {
            $Uri += "&name=" + $VMName
        }
        if ($HostID) {
            $Uri += "&host_id=" + $HostID
        }
        $Uri += "&case=insensitive"

        #Get VMs
        try {
            $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
            return
        }

        $Response.virtual_machines | Foreach-Object {
            if ($_.deleted_at -as [DateTime]) {
                $DeletedDate = Get-Date -Date $_.deleted_at
            }
            else {
                $DeletedDate = $null
            }

            $CustomObject = [PSCustomObject] @{
                PSTypeName       = 'HPE.SimpliVity.VirtualMachine'
                PolicyId         = $_.policy_id
                CreateDate       = Get-date -Date $_.created_at
                PolicyName       = $_.policy_name
                DataStoreName    = $_.datastore_name
                ClusterName      = $_.omnistack_cluster_name
                DeletedDate      = $DeletedDate
                AppAwareVmStatus = $_.app_aware_vm_status
                HostId           = $_.host_id
                HypervisorId     = $_.hypervisor_object_id
                VMName           = $_.name
                DatastoreId      = $_.datastore_id
                ReplicaSet       = $_.replica_set
                DataCenterId     = $_.compute_cluster_parent_hypervisor_object_id
                DataCenterName   = $_.compute_cluster_parent_name
                HypervisorType   = $_.hypervisor_type
                VmId             = $_.id
                State            = $_.state
                ClusterId        = $_.omnistack_cluster_id
                HypervisorIP     = $_.hypervisor_management_system
                HypervisorName   = $_.hypervisor_management_system_name
            }
            If (Get-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine') {
                Remove-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine'
            }
            #PowerShell list view is limited to 4 properties maximum. Use ps1xml files for more refined output control
            Update-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine' -DefaultDisplayPropertySet VMName, ClusterName, DataStoreName, PolicyName
            $CustomObject
        }
    }
}

<#
.SYNOPSIS
    Shutdown one or more Omnistack Virtual Controllers
.DESCRIPTION
     Ideally, you should only run this command when all the VMs in the cluster
     have been shutdown, or if you intend to leave at OVC's running in the cluster.

     This RESTAPI call only works if executed on the local host to the OVC. So this cmdlet
     iterates through the specifed hosts and connects to each specified host to sequentially shutdown 
     the local OVC.
.EXAMPLE
    Stop-SVTOVC -HostName <Name of SimpliVity host>

    This command waits for the affected VMs to be HA compliant, which is ideal.
.EXAMPLE
    Get-SVThost -Cluster MyCluster | Stop-SVTOVC -Force

    Stops each OVC in the specified cluster. With the =Force switch, we are NOT waiting for HA. This
    command is useful when shutting down the entire SimpliVity cluster. This cmdlet ASSUMES you have ideally 
    shutdown all the VMs in the cluster prior to powering off the OVCs.

    HostName is passed in from the pipeline, using the property name 
.EXAMPLE
    '10.10.57.59','10.10.57.61' | Stop-SVTOVC -Force

    Stops the specified OVCs one after the other. This cmdlet ASSUMES you have ideally shutdown all the affected VMs 
    prior to powering off the OVCs.

    Hostname is passed in them the pipeline by value. Same as:
    Stop-SVTOVC -Hostname @(''10.10.57.59','10.10.57.61') -Force
.INPUTS
    [System.String[]]
    [HPE.SimpliVity.Host]
.OUTPUTS
    [System.Management.Automation.PSCustomObject]
.NOTES
	Tested with SVT 3.7.7
#>
function Stop-SVTOVC {
[cmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelinebyPropertyName=$true)]
        [System.String[]]$HostName,

        [Switch]$Force
    )

    begin {
        # First we need to get all the hosts in the Federation. We will be shutting down one or more OVCs, so we may lose 
        # access to this information
        $allHosts = Get-SVTHost
    }

    process {
        foreach ($thisHostName in $Hostname) {
            # grab this host object from the collection
            $thisHost = $allHosts | Where-Object Hostname -eq $thisHostName
            Write-Verbose $($thishost | Select-Object Hostname, HostID)
            
            # Now connect to this host, using the existing credentials saved to global variable
            Connect-SVT -OVC $thisHost.ManagementIP -Credential $SVTConnection.OVCcred -IgnoreCertReqs | Out-Null
            Write-Verbose $SVTConnection 
    
            # Now shutdown the OVC on this host
            $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	                    'Accept' = 'application/json'
                        'Content-Type' = 'application/vnd.simplivity.v1.1+json'}
            
            if($Force) {
                # Don't wait for HA, powerdown the OVC without waiting
                $Body = @{'ha_wait' = $false} | ConvertTo-Json
            }
            else {
                # Wait for all affected VMs to be HA compliant.
                $Body = @{'ha_wait' = $true} | ConvertTo-Json
            }

            $Uri = $Global:SVTConnection.OVC + '/api/hosts/' + $thisHost.HostID + '/shutdown_virtual_controller'
        
            # stop the OVC on this Host
            try {
                $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.Shutdown_Status | Foreach-Object {
                [PSCustomObject] @{
                    OVC                = $thisHost.ManagementIP
                    ShutdownStatus     = $_.Status                  #Should bt IN_PROGRESS if it worked
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Get the shutdown status of one or more Omnistack Virtual Controllers
.DESCRIPTION
     This RESTAPI call only works if executed on the local host to the OVC. So this cmdlet
     iterates through the specifed hosts and connects to each specified host to sequentially get the status.

     This RESTAPI call only works if status is "None" (i.e. the OVC is responsive. However, this cmdlet is
     still useful to identify unresponsive OVCs. 
.EXAMPLE
    Get-SVTOVCShutdownStatus -HostName <Name of SimpliVity host>
  
.EXAMPLE
    Get-SVThost -Cluster MyCluster | Get-SVTOVCShutdownStatus

    Shows all shutdown status for all the OVCs in the specified cluster
    HostName is passed in from the pipeline, using the property name 
.EXAMPLE
    '10.10.57.59','10.10.57.61' | Get-SVTOVCShutdownStatus

    Hostname is passed in them the pipeline by value. Same as:
    Get-SVTOVCShutdownStatus -Hostname @(''10.10.57.59','10.10.57.61')
.INPUTS
    [System.String[]]
    [HPE.SimpliVity.Host]
.OUTPUTS
    [System.Management.Automation.PSCustomObject]
.NOTES
	Tested with SVT 3.7.7
#>
function Get-SVTOVCShutdownStatus {
[cmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelinebyPropertyName=$true)]
        [System.String[]]$HostName,

        [Switch]$Force
    )

    begin {
        # Get all the hosts in the Federation.
        $allHosts = Get-SVTHost
    }

    process {
        foreach ($thisHostName in $Hostname) {
            # grab this host object from the collection
            $thisHost = $allHosts | Where-Object Hostname -eq $thisHostName
            Write-Verbose $($thishost | Select-Object Hostname, HostID)
            
            # Now connect to this host, using the existing credentials saved to global variable
            try {
                Connect-SVT -OVC $thisHost.ManagementIP -Credential $SVTConnection.OVCcred -IgnoreCertReqs -ErrorAction Stop | Out-Null
                Write-Verbose $SVTConnection
            }
            catch {
                Write-Error "Error connecting to $($thisHost.ManagementIP) (host $thisHostName). Check that it is running"
                break
            }
    
            # Now shutdown the OVC on this host
            $Header = @{'Authorization' = "Bearer $($Global:SVTConnection.Token)"
	                    'Accept' = 'application/json'
                        'Content-Type' = 'application/vnd.simplivity.v1.1+json'}
            
            $Uri = $Global:SVTConnection.OVC + '/api/hosts/' + $thisHost.HostID + '/virtual_controller_shutdown_status'
        
            # stop the OVC on this Host
            try {
                $Response = Invoke-SVTRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                Write-Error "Error connecting to $($thisHost.ManagementIP) (host $thisHostName). Check that it is running"
                break
            }

            $Response.Shutdown_Status | Foreach-Object {
                [PSCustomObject] @{
                    OVC                = $thisHost.ManagementIP
                    ShutdownStatus     = $_.Status                  
                }
            }
        }
    }
}
