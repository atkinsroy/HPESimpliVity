###############################################################################################################
# HPESimpliVity.psm1
#
# Description:
#   This module provides management cmdlets for HPE SimpliVity via the 
#   REST API. This module has been written and tested with version 3.7.7.
#   using both VMware and Hyper-V.
#
# Download:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   VERSION 1.1.0
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext, Advisory & Professional Services
#
#   HISTORY
#   Date        Version  Description
#   05/03/2019  1.0.0    First version containing initial set of cmdlets that implement GET API calls
#   18/03/2019  1.1.0    Added cmdlets that implement POST API calls, e.g. New-SVTbackup and New-SVTclone
#
# (C) Copyright 2019 Hewlett Packard Enterprise Development LP
##############################################################################################################

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

#region Utility
# Helper function for Invoke-RestMethod to handle errors in one place. The calling function then re-throws the error, if we generate
# one here. This cmdlet either outputs a custom task object if the REST API produces a task object type, or otherwise the raw JSON.
# JSON is expected by all the 'Get' and a couple of 'Post' cmdlets, which output different object types.
function Invoke-SVTrestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Uri,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Collections.IDictionary]$Header,
        
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('get', 'post', 'delete')]
        [System.String]$Method,

        [Parameter(Mandatory = $false, Position = 3)]
        [System.Object]$Body
    )
    try {
        if ($Body) {
            $Response = Invoke-RestMethod -Uri $Uri -Headers $Header -Body $Body -Method $Method -ErrorAction Stop
        }
        else {
            $Response = Invoke-RestMethod -Uri $Uri -Headers $Header -Method $Method -ErrorAction Stop
        }
    }
    catch [System.Management.Automation.RuntimeException] {
        if ($_.Exception.Message -match "Unauthorized") {
            throw "Runtime error: Session expired, log in using Connect-SVT"
        }
        elseif ($_.Exception.Message -match "The hostname could not be parsed") {
            throw "Runtime error: You must first log in using Connect-SVT"
        }
        else {
            throw "Runtime error: $($_.Exception.Message)"  
        }
    }
    catch {
        # Catch any other error - SimpliVity might had provided a nic little message
        throw "An unexpected error occured: $($_.Exception.Message)" 
    }

    # If the JSON output is a task, convert it to a custom object of type 'HPE.SimpliVity.Task' and pass this back to the 
    # calling cmdlet. A lot of cmdlets produce task object types, so this cuts out repetition in the module.
    if ($Response.task) {
        $Response.task | ForEach-Object {
            [PSCustomObject]@{
                PStypeName      = 'HPE.SimpliVity.Task'
                TaskId          = $_.id
                State           = $_.state
                AffectedObjects = $_.affected_objects
                ErrorCode       = $_.error_code
                StartTime       = Get-Date -Date $_.start_time
                EndTime         = if ($_.end_time -as [datetime]) 
                { Get-Date -Date $_.end_time }
                else {
                    $_.end_time 
                }
                Message         = $_.message
            }
        }
    }
    else {
        # For all other object types, return the raw JSON output for the calling cmdlet to deal with.
        # Mostly the 'Get' functions. 
        $Response
    }
}

<#
.SYNOPSIS
    Show information about tasks that are executing or have finished executing in HPE SimpliVity
.DESCRIPTION
    Performing most Post/Delete calls to the SimpliVity REST API will generate task objects as output.
    Whilst these task objects are immediately returned, the task themselves will change state over time. For example, 
    when a Clone VM task completes, its state changes from IN_PROGRESS to COMPLETED.

    All cmdlets that return a JSON 'task' object, e.g. New-SVTbackup, New-SVTclone will output custom task objects of 
    type HPE.SimpliVity.Task and can then be used as input here to find out if the task completed successfully. You can 
    either specify the Task ID from the cmdlet output or, more usefully, use $SVTtask. This is a global variable that all
    'task producing' HPE SimpliVity cmdlets create. $SVTtask is overwritten each time one of these cmdlets is executed. 
.PARAMETER Task
    The task object(s). Use the global variable $SVTtask which is generated from a 'task producing' HPE SimpliVity cmdlet, like
    New-SVTbackup, New-SVTclone and Move-SVTvm.
.PARAMETER TaskId
    Alternatively, enter the taskid of a specific task. The task ID(s) is/are shown as output from a 'task producing' cmdlet.
.INPUTS
    System.String
    HPE.SimpliVity.Task
.OUTPUTS
    HPE.SimpliVity.Task
.EXAMPLE
    PS C:\> Get-SVTtask

    Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates something
.EXAMPLE
    PS C:\> New-SVTbackup -VMname MyVM
    PS C:\> Get-SVTtask

    Shows the state of the task executed from the New-SVTbackup cmdlet.
.EXAMPLE
    PS C:\> Get-SVTvm | Where-Object VMname -match '^A' | New-SVTclone
    PS C:\> Get-SVTtask

    The first command enumerates all virtual machines with names beginning with the letter A and clones them.
    The second command monitors the progress of the clone tasks.
.NOTES
    Tested with HPE OmniStack 3.7.8
#>
function Get-SVTtask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeLine = $true)]
        [PSobject]$Task = $SVTtask
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }
    }

    process {
        foreach ($ThisTask in $Task) {
            $Uri = $($global:SVTconnection.OVC) + '/api/tasks/' + $ThisTask.TaskId

            try {
                Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get
            }
            catch {
                throw $_.Exception.Message
            }
        }
    }
}

<#
.SYNOPSIS
    Obtain an authentication token from a HPE SimpliVity OmniStack Virtual Controller (OVC).
.DESCRIPTION
    To access the SimpliVity REST API, you need to request an authentication token by issuing a request 
    using the OAuth authentication method. Once obtained, you can pass the resulting access token via the 
    HTTP header using an Authorisation Bearer token.

    The access token is stored in a global variable accessible to all HPESimpliVity cmdlets in the PowerShell session.
    Note that the access token times out after 10 minutes of inactivty. If this happens, simply run this
    cmdlet again.
.PARAMETER OVC
    The Fully Qualified Domain Name (FQDN) or IP address of any OmniStack Virtual Controller. This is the management 
    IP address of the OVC.
.PARAMETER Credential
    User generated credential as System.Management.Automation.PSCredential. Use the Get-Credential PowerShell cmdlet
    to create the credential. This can optionally be imported from a file in cases where you are invoking non-interactively.
    E.g. shutting down the OVC's from a script invoked by UPS software. 
.PARAMETER SignedCert
    Requires a trusted cert. By default the cmdlet allows untrusted self-signed SSL certificates with HTTPS 
    connections and enable TLS 1.2.
    NOTE: You don't need this with PowerShell 6.0; it supports TLS1.2 natively and allows certificate bypass 
    using Invoke-Method -SkipCertificateCheck. This is not implemented here yet.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.EXAMPLE
    PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC>

    This will securely prompt you for credentials
.EXAMPLE
    PS C:\>  $MyCredentials = Get-Credential -Message 'Enter Credentials'
    PS C:\>  Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $MyCredentials

    Create the credential first, then pass it as a parameter.
.EXAMPLE
    PS C:\>  $CredFile = "$((Get-Location).Path)\OVCcred.XML"
    PS C:\>  Get-Credential -Credential '<username@domain'| Export-CLIXML $CredFile

    Then connect to the OVC using:
    PS C:\>  Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $(Import-CLIXML $CredFile)

    This method is useful in non-iteractive sessions. Once the file is created, run the Connect-SVT
    command to connect and reconnect to the OVC, as required.
.NOTES
    Tested with HPE OmniStack 3.7.7
#>
function Connect-SVT {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$OVC,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [switch]$SignedCert
    )

    if ($SignedCert) {
        $SignedCertificates = $true
    }
    else {
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

    # 2 ways to authenticate - via an existing credential object or securely prompt for credential
    if ($Credential) {
        $OVCcred = $Credential
    }
    else {
        $OVCcred = Get-Credential -Message 'Enter credentials with authorisation to login to your OmniStack Virtual Controller (e.g. administrator@vsphere.local)'
    }

    $Uri = 'https://' + $OVC + '/api/oauth/token'

    # Case is important here with property names
    $Header = @{'Authorization' = 'Basic ' + [System.Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes('simplivity:'))
        'Accept'                = 'application/json'
    }
    
    $Body = @{'username' = $OVCcred.Username
        'password'       = $OVCcred.GetNetworkCredential().Password
        'grant_type'     = 'password'
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
 
    $global:SVTconnection = [pscustomobject]@{
        OVC                = "https://$OVC"
        Credential         = $OVCcred
        Token              = $Response.access_token
        UpdateTime         = $Response.updated_at
        Expiration         = $Response.expires_in
        SignedCertificates = $SignedCertificates
    }
    # Return connection object to the pipeline. Used by all other HPESimpliVity cmdlets.
    $global:SVTconnection
}

<#
.SYNOPSIS
    Get the REST API version and SVTFS version of the HPE SimpliVity installation
.DESCRIPTION
    Get the REST API version and SVTFS version of the HPE SimpliVity installation
.INPUTS
    None
.OUTPUTS
    System.Management.Automation.PSCustomObject
.EXAMPLE
    PS C:\> Get-SVTversion

    Shows version information for the REST API and SVTFS.
.NOTES
    Tested with HPE OmniStack 3.7.7
#>
Function Get-SVTversion {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }
   
    $Uri = $($global:SVTconnection.OVC) + '/api/version'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response | ForEach-Object {
        [PSCustomObject]@{
            'RESTAPIversion' = $_.REST_API_Version
            'SVTFSversion'   = $_.SVTFS_Version 
        }
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    System.String
    HPE.SimpliVity.Cluster
    HPE.SimpliVity.Host
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Metric
.NOTES
    General notes
#>
function Get-SVTmetric {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'SVTobject')]
        [psobject]$SVTobject,
        
        [parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Cluster')]
        [string[]]$ClusterName,

        [parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Host')]
        [string[]]$HostName,

        [parameter(Mandatory = $false, Position = 0, ParameterSetName = 'VirtualMachine')]
        [string[]]$VMName,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$TimeOffset = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Range = 43200,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'MINUTE'
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }
    }

    process {
        if ($SVTobject) {
            $InputObject = $SVTObject
        }
        elseif ($ClusterName) {
            $InputObject = $ClusterName
        }
        elseif ($HostName) {
            $InputObject = $HostName
        }
        elseif ($VMName) {
            $InputObject = $VMName
        }
        else {
            throw "Something went wrong"
        }
        foreach ($Item in $InputObject) {
            $TypeName = $Item | Get-Member | Select-Object -ExpandProperty TypeName -Unique
            Write-Verbose $TypeName
            if ($TypeName -eq 'HPE.SimpliVity.Cluster') {
                $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $Item.ClusterId + '/metrics'
                $ObjectName = $Item.ClusterName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.Host') {
                $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $Item.HostId + '/metrics'
                $ObjectName = $item.HostName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.VirtualMachine') {
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $Item.VmId + '/metrics'
                $ObjectName = $Item.VMname
            }
            elseif ($ClusterName) {
                try {
                    $ClusterId = Get-SVTcluster -ClusterName $Item -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
                    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/metrics'
                    $ObjectName = $ClusterName
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            elseif ($HostName) {
                try {
                    $HostId = Get-SVThost -HostName $Item -ErrorAction Stop | Select-Object -ExpandProperty HostId
                    $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/metrics'
                    $ObjectName = $HostName
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                try {
                    $VmId = Get-SVTvm -VMname $Item -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/metrics'
                    $ObjectName = $VMName
                }
                catch {
                    throw $_.Exception.Message
                }
            }

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This outputs each Metric with a date and some values
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = $_.name
                $_.data_points | ForEach-Object {
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = $_.date
                        Read  = $_.reads
                        Write = $_.writes
                    }
                }
            }

            #Transpose the custom object to output each date with the value for each metric
            $CustomObject | Sort-Object -Property Date | Group-Object -Property Date | ForEach-Object {
                $Property = [ordered]@{ Date = $_.Name }
                $_.Group | Foreach-object {
                    $Property += @{ 
                        "$($_.Name)Read"  = $_.Read 
                        "$($_.Name)Write" = $_.Write
                    }
                }
                $Property += @{ ObjectName = $ObjectName }
                New-Object -TypeName PSObject -Property $Property
            }
            # Graph stuff goes here.
        }
    }

    end {
    }
}

#endregion Utility

#region Backup

<#
.SYNOPSIS
    Display information about HPE SimpliVity backups.
.DESCRIPTION
    Show backup information from the HPE SimpliVity Federation. By default SimpliVity backups from the last 24 hours are 
    shown, but this can be overridden by specifying the -Hour parameter. Alternatively, specify either a backup name, the 
    -All parameter or the -Latest parameter. Further filtering of these three main parameters can be done by specifying 
    one or more of the additional optional parameters
.PARAMETER BackupName
    Show the specified backups. This cannot be used with -Hour, -All or -Latest parameters.
.PARAMETER All
    Show all backups. This might take a while depending on the number of backups. This cannot be used with the -Hour,
    -BackupName or -Latest parameters.

    There is a known issue where setting the limit above 3000 can result in out of memory errors, so the -Limit parameter can currently 
    be set between 1 and 3000.
    3.7.8 Release Notes: OMNI-53190 REST API Limit recommendation for REST GET backup object calls
    3.7.8 Release Notes: OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints
.PARAMETER Latest
    Show the latest backup for every unique virtual machine. This might take a while depending on the number of backups. 
.PARAMETER Hour
    The number of hours preceeding to report on. By default, the last 24 hours of backups are shown. -Hour is ignored if used with

.PARAMETER VMname
    Show backups for the specified virtual machine only.
.PARAMETER DataStoreName
    Show backups from the specified datastore only.
.PARAMETER ClusterName
    Show backups from the specified HPE SimpliVity Cluster only.
.EXAMPLE
    PS C:\> Get-SVTbackup

    Show the last 24 hours of backups from the SimpliVity Federation.
.EXAMPLE
    PS C:\> Get-SVTbackup -Hour 48 | Select-Object VMname, DataStoreName, SentMB, UniqueSizeMB | Format-Table -Autosize

    Show backups up to 48 hours old and select specific properties to display
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName '2019-05-05T00:00:00-04:00'

    Shows the backup(s) with the specified backup name.
.EXAMPLE
    PS C:\> Get-SVTbackup -All

    Shows all backups. This might take a while to complete.
    
    Note: By default, the Limit (the maximum number of backups returned) is set to 500.
.EXAMPLE
    PS C:\> Get-SVTbackup -Latest

    Show the last backup for every VM. This might take a while to complete, because all backups are enumerted before determining 
    the latest backup for each virtual machine.

    Note: By default, the Limit (the maximum number of backups returned) is set to 500. There is a known issue where setting 
    the limit above 3000 can result in out of memory errors, so the -Limit parameter can currently be set between 1 and 3000.
    3.7.8 Release Notes: OMNI-53190 REST API Limit recommendation for REST GET backup object calls
    3.7.8 Release Notes: OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname MyVM

    Shows backups in the last 24 hours for the specified VM only.
.EXAMPLE
    PS C:\> Get-SVTbackup -Datastore MyDatastore -All

    Shows all backups on the specified datastore.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Backup
.NOTES
    Tested with SVT 3.7.8
#>
function Get-SVTbackup {
    [CmdletBinding(DefaultParameterSetName = 'ByHour')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByBackupName')]
        [System.String]$BackupName,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'AllBackup')]
        [switch]$All,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'LatestBackup')]
        [switch]$Latest,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByHour')]
        [System.String]$Hour = 24,

        [Parameter(Mandatory = $false, ParameterSetName = 'AllBackup')]
        [Parameter(Mandatory = $false, ParameterSetName = 'LatestBackup')]
        [ValidateRange(1, 3000)]   # 3.7.8 Release Notes recommend 3,000 records to avoid out of memory errors
        [Int]$Limit = 500,
        
        [System.String]$VMname,

        [System.String]$DatastoreName,

        [System.String]$ClusterName
    )
   
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $BackupObject = @()
    
    $Uri = $($global:SVTconnection.OVC) + '/api/backups?case=insensitive'
    
    # If -All or -Latest are specified grab everything, but use -Limit to constrain the number of records.
    if ($All -or $Latest) {
        $Uri += "&offset=0&limit=$Limit"
        if ($Limit -le 500) {
            Write-Warning "Limiting the number of backup objects to display to $Limit. This improves perforamnce but some backups may not be included"
        }
        else {
            Write-Warning "You have chosen a limit of $Limit backup objects. This command may take a long time to complete"
        }
    }
    else {
        if ($BackupName) {
            Write-Warining "Backup names are currently case sensitive"
            $BackupName = "$BackupName*" 
            $Uri += '&name=' + ($BackupName -replace '\+', '%2B')
        }
        else {
            # Get date for specified hour
            $StartDate = (get-date).AddHours(-$Hour).ToUniversalTime()
            $CreatedAfter = "$(get-date $StartDate -format s)Z"
            $Uri += '&created_after=' + $CreatedAfter
            Write-Verbose "Displaying backups from the last $Hour hours, (created after $CreatedAfter)"
        }
    }
    
    #
    # There are two known issues in release notes. 
    # 1. You can't filter on more than one item. Filtering on Backup Name, DataStore and ClusterName together produces unexpected results.
    # 2. its case sensitive only (this is opposite to what release notes says). /backups GET RESTAPI ignore the caseinsensitive parameter.
    #
    # So at present, don't filter using the API, get all objects and and filter in PowerShell later. This fixes both issues. 
    # We are filtering on 'created_after' by default so hopefully there are not too many objects. 
    # This is less efficient than the RESTaPI doing the filtering (if it worked) but produces the expected results.
    #
    # Hopefully, this will be fixed in a later release.
    # 
    #if ($VMname) {
    #    $Uri += '&virtual_machine_name=' + $VMname
    #}
    #if ($DataStoreName) {
    #    $Uri += '&datastore_name=' + $DataStoreName
    #}
    #if ($ClusterName) {
    #    $Uri += '&omnistack_cluster_name=' + $ClusterName
    #}

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.backups | ForEach-Object {
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

        $CustomObject = [PSCustomObject]@{
            PSTypeName       = 'HPE.SimpliVity.Backup'
            VMname           = $_.virtual_machine_name
            CreateDate       = Get-Date -Date $_.created_at
            ConsistencyType  = $_.consistency_type
            BackupType       = $_.type
            DataStoreName    = $_.datastore_name
            AppConsistent    = $_.application_consistent
            VMId             = $_.virtual_machine_id
            ParentId         = $_.compute_cluster_parent_hypervisor_object_id
            BackupId         = $_.id
            BackupState      = $_.state
            ClusterId        = $_.omnistack_cluster_id
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
            DatastoreId      = $_.datastore_id
            DataCenterName   = $_.compute_cluster_parent_name
            HypervisorType   = $_.hypervisor_type
            SentDuration     = $_.sent_duration
        }
        $BackupObject += $CustomObject
    }
        
    # Added this block to get around case sensitivity/duplicate filter bugs in the /backups GET RESTAPI. These commands are iterative so you 
    # could end up with no objects. e.g. user specifies a datastore where there are no backups for a specified VM
    if ($VMname) {
        $BackupObject = $BackupObject | Where-Object VMname -eq $VMname
    }
    if ($DataStoreName) {
        $BackupObject = $BackupObject | Where-Object DatastoreName -eq $DataStoreName
    }
    if ($ClusterName) {
        $BackupObject = $BackupObject | Where-Object ClusterName -match $ClusterName  # allows partial names or FQDN
    }

    # Finally, if -Latest was specified, just display the lastest backup of each VM
    if ($Latest) {
        $VMlist = ($BackupObject).VMname | Sort-Object -Unique
        foreach ($VM in $VMlist) {
            Write-Verbose $VM
            $BackupObject | Where-Object VMname -eq $VM | Sort-Object CreateDate -Descending | Select-Object -First 1
        }
    }
    else {
        $BackupObject
    }
}

<#
.SYNOPSIS
    Create one or more new HPE SimpliVity backups
.DESCRIPTION
    Creates a backup of one or more virtual machines hosted on HPE SimpliVity. Either specify the VM names via the 
    VMname parameter or use Get-SVTvm output to pipe in the HPE SimpliVity VM objects to backup. Backups are directed to the
    specified destination cluster, or to the local cluster for each VM if no destination cluster name is specified. 
.PARAMETER VMname
    The virtual machine(s) to backup
.PARAMETER BackupName
    Give the backup(s) a unique name, otherwise a date stamp is used.
.PARAMETER ClusterName
    The destination cluster name. If nothing is specified, the virtual machine(s) is/are backed up locally.
.PARAMETER RetentionDay
    Retention specified in days. The default is 1 day.
.PARAMETER AppConsistent
    An indicator to show if the backup represents a snapshot of a virtual machine with data that was first flushed to disk.
    Default is false. This is a switch parameter, true if present.
.PARAMETER ConsistencyType
    There are two available options to create application consistant backups:
    1. VMware Snapshot - This is the default method used for application consistancy
    2. Microsoft VSS - refer to the admin guide for requirements and supported applications
    There is also the option to not use application consistancy (None). This is the default for this command.
.EXAMPLE
    PS C:\> New-SVTbackup -VMname MyVM -ClusterName ClusterDR

    Backup the specified VM to the specified SimpliVity cluster, using the default backup name and retention
.EXAMPLE
    PS C:\> Get-SVTvm | ? VMname -match '^DB' | New-SVTbackup -BackupName 'Manual backup prior to SQL upgrade'

    Locally backup up all VMs with names starting with 'DB' using the the specified backup name and default retention
.EXAMPLE
    PS C:\> 'vm01','vm02','vm03' | New-SVTvm -BackupName 'Long term backup' -ClusterName MyCluster -RetentionDay 90
    PS C:\> Get-SVTtask

    Backup the specified VMs to the specified cluster and with a retention of 90 days. Second command monitors the three backup tasks.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Tested with SVT 3.7.8
#>
function New-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$BackupName = "Created by $($global:SVTconnection.Credential.Username) at $(Get-Date -Format 'yyyy-MM-dd hh:mm:ss')",

        [Parameter(Mandatory = $false, Position = 3)]
        [Int]$RetentionDay = 1,

        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$AppConsistent,

        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('DEFAULT', 'VSS', 'NONE')]
        [System.String]$ConsistencyType = 'NONE'
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $Allvm = Get-SVTvm
        $AllTask = @() 
    }

    process {
        foreach ($VM in $VMname) {
            if ($ClusterName) {
                try {
                    $DestinationId = (Get-SVTcluster -ClusterName $ClusterName).ClusterId
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                # No destination cluster specified, so use cluster id local the VM being backed up.
                $DestinationId = ($allvm | Where-Object VMname -eq $VM).ClusterId
            }

            if ($AppConsistent) {
                $ApplicationConsistant = $True
            }
            else {
                $ApplicationConsistant = $False
            }


            $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

            $Body = @{'backup_name' = $BackupName
                'destination_id'    = $DestinationId
                'app_consistent'    = $ApplicationConsistant
                'consistency_type'  = $ConsistencyType
                'retention'         = $RetentionDay * 1440  # must be specified in minutes
            } | ConvertTo-Json

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/backup'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Restore one or more HPE SimpliVity virtual machines
.DESCRIPTION
    Restore one or more virtual machines hosted on HPE SimpliVity. Use Get-SVTbackup output to pipe in the 
    backup ID(s) and VMname(s) you'd like to restore. You can either specify a destination datastore or restore 
    to the local datastore for each specified backup. By default, the restore will create a new VM with the 
    same/specified name, but with a time stamp appended, or you can specify -RestoreToOriginal switch to overwrite 
    the existing virtual machine.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.PARAMETER BackupId
    The UID of the backup(s) to restore from
.PARAMETER VMname
    The virtual machine name(s)
.PARAMETER DatastoreName
    The destination datastore name
.PARAMETER RestoreToOriginal
    Whether to create a new virtual machine or overwrite the existing virtual machine
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName XXXX | Restore-SVTvm -RestoreToOriginal

    Restores the virtual machine(s) in the specified backup(s) to the original VM name(s)
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname MyVM | Sort-Object CreateDate | Select-Object -Last 1 | Restore-SVTvm

    Restores the latest backup of specified virtual machine, giving it the same name as the original VM with a data stamp appended.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Tested with SVT 3.7.8
#>
function Restore-SVTvm {
    # Elected to call this 'restore VM' rather than 'restore backup' as per the API, because it makes more sense
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $false)]
        [switch]$RestoreToOriginal
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllDataStore = Get-SVTdatastore
        $AllTask = @()
    }
    process {
        foreach ($BkpId in $BackupId) {
            $DataStoreId = $AllDataStore | 
            Where-Object DataStoreName -eq $DataStoreName | 
            Select-Object -ExpandProperty DataStoreId
            
            if ($RestoreToOriginal) {
                $RestoreVMname = $VMname
                $RestoreOriginalVM = $true
            }
            else {
                $RestoreVMname = "$VMname-restore-$(Get-Date -Format 'yyyy-MM-dd-hh-mm-ss')"
                $RestoreOriginalVM = $false
            }
            $Body = @{
                'datastore_id'         = $DataStoreId
                'virtual_machine_name' = $RestoreVMname
                'restore_original'     = $RestoreOriginalVM
            } | ConvertTo-Json

            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId + '/restore'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Delete one or more HPE SimpliVity backups
.DESCRIPTION
    Deletes one or more backups hosted on HPE SimpliVity. Use Get-SVTbackup output to pipe in the backup(s) to delete or
    specify the Backup ID, if known.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.PARAMETER BackupId
    The UID of the backup(s) to delete
.EXAMPLE
    PS C:\> Get-Backup -BackupName XXXX | Remove-SVTbackup

    Deletes the backups with the specified backup name
.EXAMPLE
    PS C:\> Get-Backup -VMname MyVM -Hour 3 | Remove-SVTbackup

    Deletes any backup that's at least 3 hours old for the specified virtual machine.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This cmdlet uses the /api/backups/<bkpId> RESTAPI delete call which creates a task to delete the specified backup ID.
    There is another delete call (/api/backups) which accepts a list of Backup ID's in the body. It might be worth investigating
    because it would be more efficient - single RESTAPI call, single task.

    Tested with SVT 3.7.7
#>
function Remove-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Delete -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }

    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Stop-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId + '/cancel'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }

    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Copy-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        $ClusterId = Get-SVTcluster | Where-Object ClusterName -eq $ClusterName | Select-Object -ExpandProperty ClusterId
        $AllTask = @()
    }
    
    process {
        foreach ($thisbackup in $BackupId) {
            $Body = @{
                'destination_id' = $ClusterId
            } | ConvertTo-Json

            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $thisbackup + '/copy'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Lock-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId + '/lock'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Rename-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$BackupName
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Body = @{
                'backup_name' = $BackupName
            } | ConvertFrom-Json

            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId + '/rename'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Set the retention of existing HPE SimpliVity backups
.DESCRIPTION
    Change the retention on existing SimpliVity backup.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.

    Note: There is currently a known issue with the REST API that prevents you from setting retention times that will
    cause backups to immediately expire. As a consequence, this cmdlet will only allow you to increase backup retentions.
    if you try to decrease the retention for a backup policy where backups will be expired, you'll receive an error in the task.
    
    OMNI-53536: Setting the retention time to a time that causes backups to be deleted fails
.PARAMETER BackupId
    The UID of the backup you'd like to set the retention for
.PARAMETER RetentionDay
    The new retention you would like to set, in days.
.EXAMPLE
    PS C:\> Get-Backup -BackupName XXXX | Set-SVTbackupRetention -RetentionDay 21
    
    Gets the backups with the specified name and sets the retention to 21 days.
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Set-SVTbackupRetention {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId,

        [Parameter(Mandatory = $true, Position = 1)]
        [Int]$RetentionDay

        # Force is supported by the API - it tells SimpliVity to set the rentention even if backups will be expired.
        # This currently doesn't work, see help. For now, this parameter is disabled so if you try to decrease the retention for
        # a backup policy where backups will be expired, you'll receive an error in the task.
        #[Parameter(Mandatory=$true, Position=2)]
        #[Switch]$Force
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()

        $Retention = $RetentionDay * 1440   # Must be specified in minutes

        if ($Force) {
            Write-Warning 'Possible deletion of some backups, depending on age and retention set'
            $ForceRetention = $true
        }
        else {
            $ForceRetention = $false
        }
    }

    process {
        # This API call accepts a list of backup Ids. However, we are creating a task per backup Id here. 
        # Using a task list with a single task may be more efficient, but its inconsistent with the other cmdlets.
        foreach ($BkpId in $BackupId) {
            $Body = @{
                'backup_id' = $BkpId
                'retention' = $Retention
                'force'     = $ForceRetention
            } | ConvertFrom-Json

            $Uri = $($global:SVTconnection.OVC) + '/api/backups/set_retention'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Update-SVTbackupUniqueSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }
        $AllTask = @()
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $($global:SVTconnection.OVC) + '/api/backups/' + $BkpId + '/calculate_unique_size'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }

    end {
        $global:SVTtask = $AllTask
    }
}

#endregion Backup

#region Datastore


<#
.SYNOPSIS
    Display HPE SimpliVity datastore information
.DESCRIPTION
    Shows datastore information from the SimpliVity Federation
.EXAMPLE
    PS C:\> Get-SVTdatastore

    Shows all datastores in the Federation
.EXAMPLE
    PS C:\> Get-SVTdatastore -DatastoreName MyDS | Export-CSV Datastore.csv

    Exports the specified datastore information to a CSV
.EXAMPLE
    PS C:\> Get-SVTdatastore | Select-Object Name, SizeGB, Policy
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.DataStore
.NOTES
    Tested with SVT 3.7.8
#>
function Get-SVTdatastore {
    [CmdletBinding()]
    param (
        [System.String]$DatastoreName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }
   
    #Get OmniStack Datastores in Federation
    $Uri = $($global:SVTconnection.OVC) + '/api/datastores?show_optional_fields=false'

    if ($DatastoreName) {
        $Uri += '&name=' + $DatastoreName
    }
    $Uri += '&case=insensitive'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.datastores | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.DataStore'
            PolicyId                 = $_.policy_id
            MountDirectory           = $_.mount_directory
            CreateDate               = Get-Date -Date $_.created_at
            PolicyName               = $_.policy_name
            ClusterName              = $_.omnistack_cluster_name
            Shares                   = $_.shares
            Deleted                  = $_.deleted
            HyperVisorId             = $_.hypervisor_object_id
            SizeGB                   = "{0:n0}" -f ($_.size / 1gb)
            DataStoreName            = $_.name
            DataCenterId             = $_.compute_cluster_parent_hypervisor_object_id
            DataCenterName           = $_.compute_cluster_parent_name
            HypervisorType           = $_.hypervisor_type
            DataStoreId              = $_.id
            ClusterId                = $_.omnistack_cluster_id
            HypervisorManagementIP   = $_.hypervisor_management_system
            HypervisorManagementName = $_.hypervisor_management_system_name
        }
    }
}

<#
.SYNOPSIS
    Create a new HPE SimpliVity datastore
.DESCRIPTION
    Creates a new datastore on the specified SimpliVity cluster. An existing backup
    policy must be assigned when creating a datastore. The datastore size can be between
    1GB and 1,048,576 GB (1,024TB)
.EXAMPLE
    PS C:\>New-SVTdatastore -DatastoreName ds01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 102400
    
    Creates a new 100TB datastore called ds01 on Cluster1 and assigns the Daily backup policy to it
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Tested with SVT 3.7.8
#>
function New-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateRange(1, 1048576)]   # Max is 1024TB (as per GUI)
        [int]$SizeGB
    )

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
        $PolicyID = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId
        $DataStoreExists = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExcludeProperty DataStoreName
    }
    catch {
        throw $_.Exception.Message
    }

    if ($DataStoreExists) {
        throw 'Specified datastore already exists'
    }

    if (-not ($ClusterId) -or -not ($PolicyId)) {
        throw 'Specified cluster name or policy name not found'
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'name'                 = $DataStoreName
        'omnistack_cluster_id' = $ClusterId
        'policy_id'            = $PolicyId
        'size'                 = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/'
  
    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Remove an HPE SimpliVity datastore
.DESCRIPTION
    Removes the SimppliVity datastore.
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    Tested with SVT 3.7.8
#>
function Remove-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId)) {
        throw 'Specified datastore name  not found'
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw "$($_.Exception.Message) This could be because VMs are still present on the datastore"
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Resize a HPE SimpliVity Datastore
.DESCRIPTION
    Resizes a specified datastore to the specified size in GB. The datastore size can be 
    between 1GB and 1,048,576 GB (1,024TB). 
.EXAMPLE
    PS C:\>Resize-SVTdatastore -DatastoreName ds01 -SizeGB 1024
    
    Resizes the specified datastore to 1TB
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    General notes
#>
function Resize-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 1048576)] # Max is 1024TB (as per GUI)
        [int]$SizeGB
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId)) {
        throw "Specified datastore $DatastoreName not found"
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'size' = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId + '/resize'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Change the backup policy on a HPE SimpliVity Datastore
.DESCRIPTION
    A SimpliVity datastore must have a backup policy assigned to it. A backup policy
    is assigned when a datastore is created. This command allows you to change the
    backup policy for the specifed datastore
.EXAMPLE
    PS C:\>Set-SVTdatastorePolicy -DatastoreName ds01 -PolicyName Weekly
    
    Assigns a new backup policy to the specified datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    General notes
#>
function Set-SVTdatastorePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$PolicyName
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId) -or -not ($PolicyId)) {
        throw 'Specified datastore or policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'policy_id' = $PolicyId
    } | ConvertTo-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId + '/set_policy'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Publish-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId)) {
        throw 'Specified datastore name not found'
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'host_name' = $ComputeNodeName
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId + '/share'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Unpublish-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId)) {
        throw 'Specified datastore name not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'host_name' = $ComputeNodeName
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId + '/unshare'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Get-SVTdatastoreComputeNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName
    )

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId)) {
        throw 'Specified datastore name not found'
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    
    $Uri = $($global:SVTconnection.OVC) + '/api/datastores/' + $DatastoreId + '/standard_hosts'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.standard_host | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName         = 'HPE.SimpliVity.ComputeNode'
            HypervisorObjectId = $_.hypervisor_object_id
            ComputeNodeIp      = $_.ip_address
            ComputeNodeName    = $_.name
            Shared             = $_.shared
            VMCount            = $_.virtual_machine_count
        }
    }
}

#endregion Datastore

#region Host
<#
.SYNOPSIS
    Display HPE SimpliVity host information
.DESCRIPTION
    Shows host information from the SimpliVity Federation.
.PARAMETER HostName
    Show the specified host only
.PARAMETER ClusterName
    Show hosts from the the specified SimpliVity cluster only
.EXAMPLE
    PS C:\> Get-SVThost

    Shows all hosts in the Federation
.EXAMPLE
    PS C:\> Get-SVThost -HostName MyHost

    Shows the specified host
.EXAMPLE
    PS C:\> Get-SVThost -ClusterName MyCluster

    Shows hosts in specified HPE SimpliVity cluster
.EXAMPLE
    PS C:\> Get-SVTHost | Where-Object DataCenter -eq MyDC | Format-List *

    Shows all properties for all hosts in specified Datacenter
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Host
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVThost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$HostName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$ClusterName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    #Get OmniStack Hosts in Federation
    $Uri = $($global:SVTconnection.OVC) + '/api/hosts?show_optional_fields=False'

    if ($HostName) {
        $Uri += '&name=' + $HostName
    }
    if ($ClusterName) {
        $Uri += '&compute_cluster_name=' + $ClusterName
    }
    $Uri += '&case=insensitive'
    
    # get hosts
    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.hosts | Foreach-Object {
        $CustomObject = [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.Host'
            PolicyEnabled            = $_.policy_enabled
            ClusterId                = $_.compute_cluster_hypervisor_object_id
            StorageMask              = $_.storage_mask
            PotentialFeatureLevel    = $_.potential_feature_level
            Type                     = $_.type
            CurrentFeatureLevel      = $_.current_feature_level
            HypervisorId             = $_.hypervisor_object_id
            ClusterName              = $_.compute_cluster_name
            ManagementIP             = $_.management_ip
            FederationIP             = $_.federation_ip
            OVCName                  = $_.virtual_controller_name
            FederationMask           = $_.federation_mask
            Model                    = $_.model
            DataCenterId             = $_.compute_cluster_parent_hypervisor_object_id
            HostId                   = $_.id
            StoreageMTU              = $_.storage_mtu
            State                    = $_.state
            UpgradeState             = $_.upgrade_state
            FederationMTU            = $_.federation_mtu
            CanRollback              = $_.can_rollback
            StorageIP                = $_.storage_ip
            ManagementMTU            = $_.management_mtu
            Version                  = $_.version
            HostName                 = $_.name
            DataCenterName           = $_.compute_cluster_parent_name
            HypervisorManagementIP   = $_.hypervisor_management_system
            ManagementMask           = $_.management_mask
            HypervisorManagementName = $_.hypervisor_management_system_name
        }
        if (Get-TypeData -TypeName 'HPE.SimpliVity.Host') {
            Remove-TypeData -TypeName 'HPE.SimpliVity.Host'
        }
        #PowerShell list view is limited to 4 default properties maximum. Use ps1xml files for more refined output control
        Update-TypeData -TypeName 'HPE.SimpliVity.Host' -DefaultDisplayPropertySet HostName, DataCenter, ClusterName, Version
        $CustomObject
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity host hardware information
.DESCRIPTION
    Shows host hardware information for the specifed host(s). Some properties are
    arrays, from the REST API response. Information in these properties can be enumerated as 
    usual. See examples for details.
.PARAMETER HostName
    Show information for the specified host only
.EXAMPLE
    PS C:\> Get-SVThost -ClusterName MyCluster | Get-SVThardware

    Shows hardware information for the hosts in the specified cluster
.EXAMPLE
    PS C:\> Get-SVThardware -HostName Host01 | Select-Object LogicalDrives

    Enumerates all of the logical drives from the specified host
.EXAMPLE
    PS C:\> (Get-SVThardware -HostName Host01).RaidCard

    Enumerate all of the RAID cares from the specified host, using dot notation
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Hardware
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVThardware {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$HostName
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }

        $allhost = Get-SVThost
    }

    process {
        foreach ($Thishost in $Hostname) {
            # Get the HostId for this host
            $HostId = ($allhost | Where-Object HostName -eq $Thishost).HostId
            
            $Uri = $($global:SVTconnection.OVC) + '/api/hosts/' + $HostId + '/hardware'
        
            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $Response.host | ForEach-Object {
                [pscustomobject]@{
                    PSTypeName       = 'HPE.SimpliVity.Hardware'
                    SerialNumber     = $_.serial_number
                    Manufacturer     = $_.manufacturer
                    ModelNumber      = $_.model_number
                    FirmwareRevision = $_.firmware_revision
                    Status           = $_.status
                    HostName         = $_.name
                    HostId           = $_.host_id
                    RaidCard         = $_.raid_card
                    Battery          = $_.battery
                    AcceleratorCard  = $_.accelerator_card
                    LogicalDrives    = $_.logical_drives
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Get-SVTcapacity {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [string[]]$HostName,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$TimeOffset = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Range = 43200,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'MINUTE'
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }

        $allhost = Get-SVThost
    }

    process {
        foreach ($Thishost in $Hostname) {
            # Get the HostId for this host
            $HostId = ($allhost | Where-Object HostName -eq $Thishost).HostId
            
            $Uri = $($global:SVTconnection.OVC) + '/api/hosts/' + $HostId + '/capacity?time_offset=' + 
            $TimeOffset + '&range=' + $Range + '&resolution=' + $Resolution
            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This outputs each Metric with a date and value
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = $_.name -replace '_',''
                $_.data_points | ForEach-Object {
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = $_.date
                        Value = $_.value
                    }
                }
            }

            #Transpose the custom object to output each date with the value for each metric
            $CustomObject | Sort-Object -Property Date | Group-Object -Property Date | ForEach-Object {
                $Property = [ordered]@{ Date = $_.Name }
                $_.Group | Foreach-object {
                    $Property += @{ 
                        "$($_.Name)" = $_.Value
                    }
                }
                $Property += @{ Host = $Thishost }
                New-Object -TypeName PSObject -Property $Property
            }
            # Graph stuff goes here.
        }
    }

    end {

    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Remove-SVThost {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript( { $_ -in (Get-SVThost).HostName })]
        [System.String]$HostName,

        [switch]$Force
    )

    try {
        $HostId = Get-SVThost -HostName $HostName -ErrorAction Stop | Select-Object -ExpandProperty HostId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($HostId)) {
        throw 'Specified hostname not found'
    }
    
    if ($force) {
        $ForceHostRemoval = $true
    }
    else {
        $ForceHostRemoval = $false
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }

    $Body = @{
        'force' = $ForceHostRemoval
    } | ConvertFrom-Json
   
    $Uri = $($global:SVTconnection.OVC) + '/api/hosts/' + $HostId + '/remove_from_federation'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Shutdown one or more Omnistack Virtual Controllers
.DESCRIPTION
     Ideally, you should only run this command when all the VMs in the cluster
     have been shutdown, or if you intend to leave OVC's running in the cluster.

     This RESTAPI call only works if executed on the local host to the OVC. So this cmdlet
     iterates through the specifed hosts and connects to each specified host to sequentially shutdown 
     the local OVC.

     Note, once executed, you'll need to reconnect back to a surviving OVC, using Connect-SVT to continue
     using the HPE SimpliVity cmdlets.
.EXAMPLE
    PS C:\> Stop-SVTovc -HostName <Name of SimpliVity host>

    This command waits for the affected VMs to be HA compliant, which is ideal.
.EXAMPLE
    PS C:\> Get-SVThost -Cluster MyCluster | Stop-SVTovc -Force

    Stops each OVC in the specified cluster. With the -Force switch, we are NOT waiting for HA. This
    command is useful when shutting down the entire SimpliVity cluster. This cmdlet ASSUMES you have ideally 
    shutdown all the VMs in the cluster prior to powering off the OVCs.

    HostName is passed in from the pipeline, using the property name 
.EXAMPLE
    PS C:\> '10.10.57.59','10.10.57.61' | Stop-SVTovc -Force

    Stops the specified OVCs one after the other. This cmdlet ASSUMES you have ideally shutdown all the affected VMs 
    prior to powering off the OVCs.

    Hostname is passed in them the pipeline by value. Same as:
    Stop-SVTovc -Hostname @('10.10.57.59','10.10.57.61') -Force
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Tested with SVT 3.7.7
#>
function Stop-SVTovc {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName,
    
        [Switch]$Force
    )
    
    begin {
        # Get all the hosts in the Federation.
        # We will be shutting down one or more OVCs, so grab all host information before we start
        try {
            $allHosts = Get-SVThost -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($thisHostName in $Hostname) {
            # grab this host object from the collection
            $thisHost = $allHosts | Where-Object Hostname -eq $thisHostName
            Write-Verbose $($thishost | Select-Object Hostname, HostId)
            
            # Now connect to this host, using the existing credentials saved to global variable
            Connect-SVT -OVC $thisHost.ManagementIP -Credential $SVTconnection.Credential -IgnoreCertReqs | Out-Null
            Write-Verbose $SVTconnection 
    
            # Now shutdown the OVC on this host
            $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'                = 'application/json'
                'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
            }
            
            if ($Force) {
                # Don't wait for HA, powerdown the OVC without waiting
                $Body = @{'ha_wait' = $false } | ConvertFrom-Json
            }
            else {
                # Wait for all affected VMs to be HA compliant.
                $Body = @{'ha_wait' = $true } | ConvertFrom-Json
            }

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $thisHost.HostId + '/shutdown_virtual_controller'
        
            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.Shutdown_Status | ForEach-Object {
                [PSCustomObject]@{
                    OVC            = $thisHost.ManagementIP
                    ShutdownStatus = $_.Status
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

    This RESTAPI call only works if status is 'None' (i.e. the OVC is responsive), which kind of renders the 
    REST API a bit useless. However, this cmdlet is still useful to identify the unresponsive (i.e shut down or 
    shutting down) OVC(s).

    Note, because we're connecting to each OVC, the connection token will point to the last OVC we successfully connect to.
    You may want to reconnect to your preferred OVC again using Connect-SVT.
.EXAMPLE
    PS C:\> Get-SVTshutdownStatus

    Connect to all OVCs in the Federation and show their shutdown status
.EXAMPLE
    PS C:\> Get-SVTshutdownStatus -HostName <Name of SimpliVity host>

.EXAMPLE
    PS C:\> Get-SVThost -Cluster MyCluster | Get-SVTshutdownStatus

    Shows all shutdown status for all the OVCs in the specified cluster
    HostName is passed in from the pipeline, using the property name 
.EXAMPLE
    PS C:\> '10.10.57.59','10.10.57.61' | Get-SVTshutdownStatus

    Hostname is passed in them the pipeline by value. Same as:
    Get-SVTshutdownStatus -Hostname @(''10.10.57.59','10.10.57.61')
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVTovcShutdownStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName,

        [Switch]$Force
    )

    begin {
        # Get all the hosts in the Federation.
        try {
            $allHosts = Get-SVThost -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($thisHostName in $Hostname) {
            # grab this host object from the collection
            $thisHost = $allHosts | Where-Object Hostname -eq $thisHostName
            Write-Verbose $($thishost | Select-Object Hostname, HostId)
            
            # Now connect to this host, using the existing credentials saved to global variable
            try {
                Connect-SVT -OVC $thisHost.ManagementIP -Credential $SVTconnection.Credential -IgnoreCertReqs -ErrorAction Stop | Out-Null
                Write-Verbose $SVTconnection
            }
            catch {
                Write-Error "Error connecting to $($thisHost.ManagementIP) (host $thisHostName). Check that it is running"
                break
            }

            $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'                = 'application/json'
                'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
            }

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $thisHost.HostId + '/virtual_controller_shutdown_status'

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                Write-Error "Error connecting to $($thisHost.ManagementIP) (host $thisHostName). Check that it is running"
                break
            }

            $Response.Shutdown_Status | ForEach-Object {
                [PSCustomObject]@{
                    OVC            = $thisHost.ManagementIP
                    ShutdownStatus = $_.Status
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Undo-SVTovcShutdown {
    "Not implementated yet"
}

#endregion Host

#region Cluster
<#
.SYNOPSIS
    Display HPE SimpliVity cluster information
.DESCRIPTION
    Shows cluster information from the SimpliVity Federation
.PARAMETER ClusterName
    Show information about the specified cluster only
.EXAMPLE
    PS C:\> Get-SVTcluster

    Shows all clusters in the Federation
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Cluster
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVTcluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$ClusterName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $($global:SVTconnection.OVC) + '/api/omnistack_clusters?show_optional_fields=false'

    if ($ClusterName) {
        $Uri += '&name=' + $ClusterName
    }
    $Uri += '&case=insensitive'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.omnistack_clusters | ForEach-Object {
        $CustomObject = [PSCustomObject]@{
            PSTypeName          = 'HPE.SimpliVity.Cluster'
            DataCenterName      = $_.hypervisor_object_parent_name
            ArbiterConnected    = $_.arbiter_connected
            DataCenterId        = $_.hypervisor_object_parent_id
            Type                = $_.type
            Version             = $_.version
            HypervisorClusterId = $_.hypervisor_object_id
            Members             = $_.members
            ClusterName         = $_.name
            ArbiterIP           = $_.arbiter_address
            HypervisorType      = $_.hypervisor_type
            ClusterId           = $_.id
            HypervisorIP        = $_.hypervisor_management_system
            HypervisorName      = $_.hypervisor_management_system_name
        }
        #if (Get-TypeData -TypeName 'HPE.SimpliVity.Cluster') {
        #    Remove-TypeData -TypeName 'HPE.SimpliVity.Cluster'
        #}
        #PowerShell list view is limited to 4 default properties maximum. Use ps1xml files for more refined output control
        #Update-TypeData -TypeName 'HPE.SimpliVity.Cluster' -DefaultDisplayPropertySet ClusterName, DataCenterName, ArbiterIP, ArbiterConnected
        $CustomObject
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Get-SVTthroughput {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $($global:SVTconnection.OVC) + '/api/omnistack_clusters/throughput'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.omnistack_cluster_throughput | ForEach-Object {
        [PSCustomObject]@{
            Date                             = $_.date
            DestinationClusterHypervisorId   = $_.destination_omnistack_cluster_hypervisor_object_parent_id
            DestinationClusterHypervisorName = $_.destination_omnistack_cluster_hypervisor_object_parent_name
            DestinationClusterId             = $_.destination_omnistack_cluster_id
            DestinationClusterName           = $_.destination_omnistack_cluster_name
            SourceClusterHypervisorId        = $_.source_omnistack_cluster_hypervisor_object_parent_id
            SourceClusterHypervisorName      = $_.source_omnistack_cluster_hypervisor_object_parent_name
            SourceClusterId                  = $_.source_omnistack_cluster_id
            SourceClusterName                = $_.source_omnistack_cluster_name
            Throughput                       = $_.throughput
        }
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Get-SVTtimezone {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Uri = $($global:SVTconnection.OVC) + '/api/omnistack_clusters/time_zone_list'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Set-SVTtimezone {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript( { $_ -in (Get-SVTcluster).ClusterName })]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript( { $_ -in (Get-SVTtimezone) })]
        [System.String]$TimeZone
    )

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($ClusterId)) {
        throw 'Specified cluster name not found'
    }
    
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'time_zone' = $TimeZone
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/omnistack_clusters/' + $ClusterId + '/set_time_zone'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Set-SVTclusterConnected {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$ClusterName
    )

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($ClusterId)) {
        throw 'Specfied cluster name not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   

    $Uri = $($global:SVTconnection.OVC) + '/api/omnistack_clusters/' + $ClusterId + '/connected_clusters'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.omnistack_cluster | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName          = 'HPE.SimpliVity.ConnectedCluster'
            AllocatedCapacity   = $_.allocated_capacity
            ArbiterIP           = $_.arbiter_address
            ArbiterConnected    = $_.arbiter_connected
            CapacitySavings     = $_.capacity_savings
            CompressionRatio    = $_.compression_ratio
            ConnectedClusters   = $_.connected_clusters
            DeduplicationRatio  = $_.deduplication_ratio
            EfficiencyRatio     = $_.efficiency_ratio
            FreeSpace           = $_.free_space
            HypervisorIP        = $_.hypervisor_management_system
            HypervisorName      = $_.hypervisor_management_system_name
            HypervisorClusterId = $_.hypervisor_object_id
            DataCenterId        = $_.hypervisor_object_parent_id
            DataCenterName      = $_.hypervisor_object_parent_name
            HyperVisorType      = $_.hypervisor_type
            Clusterid           = $_.id
        }
    }
}

#endregion Cluster

#region Policy
<#
.SYNOPSIS
    Display HPE SimpliVity backup policy rule information
.DESCRIPTION
    Shows the rules of all backup policies from the SimpliVity Federation
.EXAMPLE
    PS C:\> Get-SVTpolicy

    Shows all backup policy rules
.EXAMPLE
    PS C:\> Get-SVTpolicy -PolicyName Silver

    Shows the specified backup policy
.EXAMPLE
    PS C:\> Get-SVTpolicy | Where RetentionDay -eq 7

    Show policies that have a retention of 7 days
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Policy
.NOTES
    Tested with SVT 3.7.8
#>
function Get-SVTpolicy {
    [CmdletBinding()]
    param (
        [System.String]$PolicyName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $($global:SVTconnection.OVC) + '/api/policies?case=insensitive'

    if ($PolicyName) {
        $Uri += '&name=' + $PolicyName
    }
    

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.policies | ForEach-Object {
        $PolicyName = $_.name
        $PolicyId = $_.id
        if ($_.rules) {
            $_.rules | ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName            = 'HPE.SimpliVity.Policy'
                    PolicyName            = $PolicyName
                    PolicyId              = $PolicyId
                    DestinationId         = $_.destination_id
                    EndTime               = $_.end_time
                    DestinationName       = $_.destination_name
                    ConsistencyType       = $_.consistency_type
                    FrequencyHour         = $_.frequency / 60
                    ApplicationConsistent = $_.application_consistent
                    RuleNumber            = $_.number
                    StartTime             = $_.start_time
                    MaxBackup             = $_.max_backups
                    Day                   = $_.days
                    RuleId                = $_.id
                    RetentionDay          = [math]::Round($_.retention / 1440)
                }
            }
        }
        else {
            [PSCustomObject]@{
                PSTypeName = 'HPE.SimpliVity.Policy'
                PolicyName = $PolicyName
                PolicyId   = $PolicyId
            }
        }
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function New-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript( { $_ -notin (Get-SVTpolicy).PolicyName })]
        [System.String]$PolicyName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'name' = $PolicyName
    } | ConvertTo-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/policies/'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Set-SVTpolicy {
    [CmdletBinding(DefaultParameterSetName = 'ByAllDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByWeekday')]
        [array]$WeekDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByMonthDay')]
        [array]$MonthDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByLastDay')]
        [switch]$LastDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByAllDay')]
        [switch]$All,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $false, Position = 3)]
        [System.String]$StartTime = '00:00',

        [Parameter(Mandatory = $false, Position = 4)]
        [System.String]$EndTime = '00:00',

        [Parameter(Mandatory = $false, Position = 5)]
        [System.String]$FrequencyMin = 0,

        [Parameter(Mandatory = $false, Position = 6)]
        [int]$RetentionDay = 1,

        [Parameter(Mandatory = $false, Position = 7)]
        [bool]$AppConsistent = $false,

        [Parameter(Mandatory = $false, Position = 8)]
        [ValidateSet('NONE', 'DEFAULT', 'VSS', 'FAILEDVSS', 'NOT_APPLICABLE')]
        [System.String]$ConsistencyType = 'NONE',

        [Parameter(Mandatory = $false, Position = 9)]
        [switch]$ReplaceRules
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($PolicyId) -or -not ($ClusterId)) {
        throw 'Specified policy name or cluster name not found'
    }

    if ($WeekDay) {
        foreach ($day in $WeekDay) {
            if ($day -notmatch '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$') {
                throw 'Invalid day entered, you must enter weekday in the form "Mon", "Mon,Fri" or "Mon,Thu,Sat"'
            }
        }
        $TargetDay = $WeekDay -join ','
    }
    elseif ($MonthDay) {
        foreach ($day in $MonthDay) {
            if ($day -notmatch '^([1-9]|[12]\d|3[01])$') {
                throw 'Invalid day entered, you must enter month day(s) in the form "1", "1,15" or "1,12,24"'
            }
        }
        $TargetDay = $MonthDay -join ','
    }
    elseif ($LastDay) {
        $TargetDay = 'last'
    }
    else {
        $TargetDay = 'all'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'destination_id'         = $ClusterId
        'frequency'              = $FrequencyMin
        'retention'              = $RetentionDay * 1440
        'days'                   = $TargetDay
        'start_time'             = $StartTime
        'end_time'               = $EndTime
        'application_consistent' = $AppConsistent
        'consistency_type'       = $ConsistencyType
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/policies/' + $PolicyId + '/rules'

    if ($ReplaceRules) {
        $Uri += "&replace_all_rules=$true"
    }
    else {
        $Uri += "&replace_all_rules=$false"
    }

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Update-SVTpolicy {
    "Not implemented yet"
    'bit tricky - input policy id and rule id, output similar in complexity to Set cmdlet'
    'include a -Remove to remove the rule too, this is a delete call.'
    'not in psd1'
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Rename-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript( { $_ -notin (Get-SVTpolicy).PolicyName })]
        [System.String]$NewPolicyName
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PoliciyId
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($PolicyId)) {
        throw 'Specified policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'name' = $NewPolicyName
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/policies/' + $PolicyId + '/rename'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Remove-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId
        "policyid = $policyid"
    }
    catch {
        throw $_.Exception.Message
    }

    if ($null -eq $PolicyId) {
        throw 'Specified policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Uri = $($global:SVTconnection.OVC) + '/api/policies/' + $PolicyId

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Suspend-SVTpolicy {
    [CmdletBinding(DefaultParameterSetName = 'ByFederation')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByCluster')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHost')]
        [System.String]$HostName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByFederation')]
        [switch]$Federation
    )

    if ($ClusterName) {
        try {
            $TargetId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($TargetId)) {
            throw 'Specified cluster name not found'
        }
    }
    elseif ($HostName) {
        try {
            $TargetId = Get-SVThost -HostName $HostName -ErrorAction Stop | Select-Object -ExpandProperty HostId
            $TargetType = 'host'
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($TargetId)) {
            throw 'Specified host name not found'
        }
    }
    else {
        $TargetId = ''
        $TargetType = 'federation'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/policies/suspend'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Resume-SVTpolicy {
    [CmdletBinding(DefaultParameterSetName = 'ByFederation')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByCluster')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHost')]
        [System.String]$HostName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByFederation')]
        [switch]$Federation
    )

    if ($ClusterName) {
        try {
            $TargetId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($TargetId)) {
            throw 'Specified cluster name not found'
        }
    }
    elseif ($HostName) {
        try {
            $TargetId = Get-SVThost -HostName $HostName -ErrorAction Stop | Select-Object -ExpandProperty HostId
            $TargetType = 'host'
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($TargetId)) {
            throw 'Specified host name not found'
        }
    }
    else {
        $TargetId = ''
        $TargetType = 'federation'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
    }
   
    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertFrom-Json

    $Uri = $($global:SVTconnection.OVC) + '/api/policies/resume'

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Get-SVTpolicyScheduleReport {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }
   
    $Uri = $($global:SVTconnection.OVC) + '/api/policies/policy_schedule_report'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.policy_schedule_report | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName                    = 'HPE.SimpliVity.ScheduleReport'
            DailyBackupRate               = $_.daily_backup_rate
            BackupRateLevel               = $_.backup_rate_level
            DailyBackupRateLimit          = $_.daily_backup_rate_limit
            ProjectedRetainedBackups      = $_.projected_retained_backups
            ProjectedRetainedBackupsLevel = $_.projected_retained_backups_level
            RetainedBackupsLimit          = $_.retained_backups_limit
        }
    }
}

#endregion Policy

#region VirtualMachine
<#
.SYNOPSIS
    Display information about VMs running on HPE SimpliVity hosts/storage
.DESCRIPTION
    Display information about all VMs running in the HPE SimpliVity Federation. Optionally
    you can get a specific host first, using Get-SVThost and pipe the output into this 
    cmdlet to show just he VMs on this host (or hosts). Or specify the HostId, if you know it.
.EXAMPLE
    PS C:\> Get-SVTvm

    Shows all virtual machines in the Federation
.EXAMPLE
    PS C:\> Get-SVTvm -VMname MyVM | Out-GridView -Passthru | Export-CSV FilteredVMList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports 
    this to a CSV
.EXAMPLE
    PS C:\> Get-SVThost -ClusterName ProdCluster | Get-SVTvm | Select-Object Name, SizeGB, Policy

    Show just the VMs from the specified host or hosts.
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.VirtualMachine
.NOTES
    Tested with SVT 3.7.7
#>
function Get-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$VMname,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $false, Position = 3, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$HostId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }
    }
 
    process {
        $Uri = $($global:SVTconnection.OVC) + '/api/virtual_machines?show_optional_fields=false&case=insensitive'
        
        if ($VMname) {
            $Uri += '&name=' + $VMname
        }
        if ($DataStoreName) {
            $Uri += '&datastore_name=' + $DataStoreName
        }
        if ($ClusterName) {
            $Uri += '&omnistack_cluster_name=' + $ClusterName
        }
        if ($HostId) {
            $Uri += '&host_id=' + $HostId
        }

        try {
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        $Response.virtual_machines | ForEach-Object {
            if ($_.deleted_at -as [DateTime]) {
                # Deleted VMs have an empty HostID but the API returns them when you specify a HostID.
                # So exclude deleted VMs if HostID is specified
                if ($HostID) {
                    Return
                }
                else {
                    $DeletedDate = Get-Date -Date $_.deleted_at
                }
            }
            else {
                $DeletedDate = $null
            }

            $CustomObject = [PSCustomObject]@{
                PSTypeName               = 'HPE.SimpliVity.VirtualMachine'
                PolicyId                 = $_.policy_id
                CreateDate               = Get-date -Date $_.created_at
                PolicyName               = $_.policy_name
                DataStoreName            = $_.datastore_name
                ClusterName              = $_.omnistack_cluster_name
                DeletedDate              = $DeletedDate
                AppAwareVmStatus         = $_.app_aware_vm_status
                HostId                   = $_.host_id
                HypervisorId             = $_.hypervisor_object_id
                VMname                   = $_.name
                DatastoreId              = $_.datastore_id
                ReplicaSet               = $_.replica_set
                DataCenterId             = $_.compute_cluster_parent_hypervisor_object_id
                DataCenterName           = $_.compute_cluster_parent_name
                HypervisorType           = $_.hypervisor_type
                VmId                     = $_.id
                State                    = $_.state
                ClusterId                = $_.omnistack_cluster_id
                HypervisorManagementIP   = $_.hypervisor_management_system
                HypervisorManagementName = $_.hypervisor_management_system_name
            }
            if (Get-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine') {
                Remove-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine'
            }
            #PowerShell list view is limited to 4 default properties maximum. Use ps1xml files for more refined output control
            Update-TypeData -TypeName 'HPE.SimpliVity.VirtualMachine' -DefaultDisplayPropertySet VMname, ClusterName, DataStoreName, PolicyName
            $CustomObject
        }
    }
}

<#
.SYNOPSIS
    Clone one or more Virtual Machines hosted on SimpliVity storage/hosts
.DESCRIPTION
     This cmdlet will clone a given VM or VMs up to five times. It accepts multiple
     SimpliVity Virtual Machine objects and will execute four clone operations
     simultaneously. If there are multiple clones, the cmdlet waits so that only a 
     maximum of four clones are executing at once.

     If executing multiple clone operations, it is recommended to specify the -verbose 
     parameter so you can monitor what is going on.
.PARAMETER VMname
    Specify one or more VMs to clone
.PARAMETER NumberOfClones
    Specify the number of clones - 1 to 5.
.PARAMETER AppConsistent
    An indicator to show if the backup represents a snapshot of a virtual machine with data that 
    was first flushed to disk
.PARAMETER ConsistencyType
    The type of backup used for the clone method, DEFAULT is crash-consistent, VSS is
    application-consistent using VSS and NONE is application-consistent using a snapshot
.EXAMPLE
    PS C:\> New-SVTclone -VMname NewVM1
  
    Creates a new clone with the name of the original VM plus a datestamp.
.EXAMPLE
    PS C:\> Get-SVTvm | ? {VMname -match 'SQL'} | New-SVTclone -Verbose 

    This clones every VM with 'SQL' in its name, 4 at a time. Specify the -Verbose parameter
    to watch the progress. 
.EXAMPLE
    PS C:\> New-SVTclone -VMname NewVM1 -NumberOfClones 3 -Verbose
    C:\PS>Get-SVTtask

    Clone the specified VM three times. The second command monitors the cloning tasks as they execute.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Tested with SVT 3.7.7
#>
function New-SVTclone {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(1, 20)]
        [Int]$NumberOfClones = 1,

        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$AppConsistent = $false,
        
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('DEFAULT', 'VSS', 'NONE')]
        [System.String]$ConsistencyType = 'NONE'
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task = @()
    }
    process {
        foreach ($VM in $VMname) {
            1..$NumberOfClones | ForEach-Object {
                $CloneName = "$(($allVm | Where-Object VMname -eq $VM).VMname)-clone-$(Get-Date -Format 'yyyy-MM-dd-hh-mm-ss')"

                $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

                $Body = @{'virtual_machine_name' = $CloneName
                    'app_consistent'             = $AppConsistent
                    'consistency_type'           = $ConsistencyType.ToUpper()
                } | ConvertTo-Json

                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/clone'
        
                Write-Verbose "CloneName = $CloneName"
                Write-Verbose "VMid = $VMid"
                Write-Verbose "Body = $Body"
                Write-Verbose "Uri = $Uri"

                try {
                    $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                }
                catch {
                    throw $_.Exception.Message
                }

                $AllTask += $Task
                $Task

                # Wait if we have more than 4 active cloning tasks executing
                do {
                    $ActiveTask = Get-SVTtask | 
                    Where-Object State -eq "IN_PROGRESS" | 
                    Measure-Object | 
                    Select-Object -ExpandProperty Count
                    
                    Write-Verbose "There are $ActiveTask active cloning tasks"
                    if ($ActiveTask -ge 4) {
                        Write-Verbose "Sleeping 5 seconds"
                        Start-Sleep -Seconds 5
                    }
                    else {
                        break
                    }
                } while ($true)
            }
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Move-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$DataStoreName
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
            $DataStoreId = Get-SVTdatastore -PolicyName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($DatastoreId)) {
            throw 'Specified datastore not found'
        }
        $Task = @()
    }
    process {
        foreach ($VM in $VMname) {
            $VMnameCase = ($allVm | Where-Object VMname -eq $VM).VMname
            $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

            $Body = @{'virtual_machine_name' = $VMnameCase
                'destination_datastore_id'   = $DatastoreId
            } | ConvertFrom-Json

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/move'
    
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Stop-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task = @()
    }
    process {
        foreach ($VM in $VMname) {
            $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/power_off'
    
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Start-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task = @()
    }
    process {
        foreach ($VM in $VMname) {
            $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/power_on'
    
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
function Set-SVTvmPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$PolicyName 
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
            $PolicyId = Get-SVTpolicy -PolicyName $PolicyName | Select-Object -ExpandProperty PolicyId
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($PolicyId)) {
            throw 'Specified policy name not found'
        }
        $Task = @()
    }
    process {
        foreach ($VM in $VMname) {
            $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

            $Body = @{'virtual_machine_id' = $VmId
                'policy_id'                = $PolicyId
            } | ConvertFrom-Json

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/set_policy'
    
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $AllTask += $Task
            $Task
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

#endregion VirtualMachine
