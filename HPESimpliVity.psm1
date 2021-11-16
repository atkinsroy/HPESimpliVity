###############################################################################################################
# HPESimpliVity.psm1
#
# Description:
#   This module provides management cmdlets for HPE SimpliVity via the
#   REST API. This module has been tested with the VMware version only.
#
# Website:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext Services
#
##############################################################################################################
$HPESimplivityVersion = '2.1.30'

<#
(C) Copyright 2021 Hewlett Packard Enterprise Development LP

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

#region Utility

# Helper function for most cmdlets that accept a hostname parameter. The user supplied hostname(s)
# is/are compared to a global variable called SvtHost. This is created initially by Get-SvtHost at the beginning
# of each session and updated whenever Get-SvtHost without parameters is called.
function Resolve-SvtFullHostName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('Name')]
        [System.String[]]$HostName
    )

    begin {
        [System.String[]]$HostNotFound = @()
        [System.String[]]$FoundHost = @()
    }

    process {
        # The first $TestHost command won't generate an error if $SvtHost is not defined, the second $TestHost
        # command generates a null value error, so only perform the if block it $SvtHost is defined. We want to
        # generate the standard "Specified host not found" in all error cases.
        foreach ($ThisHost in $HostName) {
            $TestHost = $global:SvtHost.HostName | Where-Object { $_ -eq $ThisHost }

            if (-not $TestHost -and $global:SvtHost) {
                $Message = "Specified host $ThisHost not found, attempting to match host " +
                'name without domain suffix'
                Write-Verbose $Message

                $TestHost = $global:SvtHost.HostName | Where-Object { $_.Split('.')[0] -eq $ThisHost }
            }

            if ($TestHost) {
                $FoundHost += $TestHost
            }
            else {
                $HostNotFound += $ThisHost
            }
        }
    }
    end {
        if ($FoundHost) {
            if ($HostNotFound) {
                Write-Warning "The following host(s) not found: $($HostNotFound -join ', ')"
            }
            Write-Output $FoundHost | Sort-Object | Select-Object -Unique
        }
        else {
            throw 'Specified host(s) not found'
        }
    }
}

# Helper function to return the embedded error message in the body of the response from the API, rather
# than a generic runtime (400,404) error. Called exclusively by Invoke-SvtRestMethod.
function Get-SvtError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Object]$Err
    )

    if ($PSEdition -eq 'Core') {
        # PowerShell Core editions has the embedded error available in ErrorDetails property.
        if ($Err.ErrorDetails.Message) {
            $ResponseBody = $Err.ErrorDetails.Message
            if ($ResponseBody.StartsWith('{')) {
                $ResponseBody = $ResponseBody | ConvertFrom-Json
            }
            Write-Output $ResponseBody.Message
        }
        else {
            Write-Output $Err.Exception.Message
        }
    }
    else {
        # Windows PowerShell doesn't have ErrorDetails property so use GetResponseStreams() method.
        if ($Err.Exception.Response) {
            $Result = $Err.Exception.Response.GetResponseStream()
            $Reader = New-Object System.IO.StreamReader($Result)
            $Reader.BaseStream.Position = 0
            $Reader.DiscardBufferedData()
            $ResponseBody = $Reader.ReadToEnd()
            if ($ResponseBody.StartsWith('{')) {
                $ResponseBody = $ResponseBody | ConvertFrom-Json
            }
            Write-Output $ResponseBody.Message
        }
        else {
            Write-Output $Err.Exception.Message
        }
    }
}

# Helper function that returns the local date format. Used directly by Get-SvtBackup and indirectly by other
# cmdlets via ConvertFrom-SvtUtc.
function Get-SvtLocalDateFormat {
    # Format dates with the local culture, except that days, months and hours are padded with zero.
    $Culture = (Get-Culture).DateTimeFormat
    # (Some cultures use single digits)
    $DateFormat = "$($Culture.ShortDatePattern)" -creplace '^d/', 'dd/' -creplace '^M/', 'MM/' -creplace '/d/', '/dd/'
    $TimeFormat = "$($Culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm', 'HH:mm'
    Write-Output "$DateFormat $TimeFormat"
}

# Helper function that returns the local date/time given the UTC (system) date/time. Used by cmdlets that return
# date properties.
# Note: Dates are handled differently across PowerShell editions. With Desktop, dates in the UTC format are
# correctly left as strings (e.g. '2020-06-03T22:00:00Z' ) when converting json to a PSObject. However, with Core,
# UTC formatted dates are incorrectly converted to the local date/time (e.g. 03/06/2020 22:00:00, ignoring UTC
# offset). In the former case, its easy to convert to local time as the date is formatted for the local culture.
# In the latter case, the UTC date/time must be converted to local date/time first and then formatted. This
# behavior may change in future versions of Core.
function ConvertFrom-SvtUtc {
    [CmdletBinding()]
    param (
        # string or date object
        [Parameter(Mandatory)]
        $Date
    )

    if ($Date -as [datetime]) {
        $LocalFormat = Get-SvtLocalDateFormat
        if ($PSEdition -eq 'Core') {
            $TimeZone = [System.TimeZoneInfo]::Local
            $LocalDate = [System.TimeZoneInfo]::ConvertTimeFromUtc($Date, $TimeZone)
            $ReturnDate = Get-Date -Date $LocalDate -Format $LocalFormat
        }
        else {
            $ReturnDate = Get-Date -Date $Date -Format $LocalFormat
        }
        Write-Output $ReturnDate
    }
    else {
        # The API returns 'NA' to represent null values.
        Write-Output $null
    }
}

# Helper function for Get-SvtBackup when the -Date parameter is specified. The function validates the date specified
# as well as determining whether or not a time is specified. The function returns start and end date/times.
function Get-SvtDateRange {
    [CmdletBinding()]
    param (
        # string or date object
        [Parameter(Mandatory)]
        $Date
    )
    $Culture = Get-Culture
    $LocalFull = Get-SvtLocalDateFormat
    $LocalDate = ($LocalFull -split ' ')[0]
    try {
        # Date only specified
        $null = [System.DateTime]::ParseExact($Date, $LocalDate, $Culture)

        Write-Verbose "Date only specified, showing 24 hour range"
        $StartDate = Get-Date -Date "$Date"
        $EndDate = $StartDate.AddMinutes(1439)
        $DateRange = [PSCustomObject] @{
            After  = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
            Before = "$(Get-Date $($EndDate.ToUniversalTime()) -format s)Z"
        }
    }
    catch {
        Write-verbose "Date by itself not specified, trying full date and time"
    }

    if (-Not $DateRange) {
        try {
            # Date and time specified
            $null = [System.DateTime]::ParseExact($Date, $LocalFull, $Culture)

            Write-Verbose "Date and time specified, showing backups with this explicit creation date/time"
            $StartDate = Get-Date -Date "$Date"
            $BothDate = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"

            $DateRange = [PSCustomObject] @{
                After  = $BothDate
                Before = $BothDate
            }
        }
        catch {
            $Message = "Invalid date specified. The date or full date and time must be in the form of '$LocalFull'"
            throw $Message
        }
    }
    Write-Output $DateRange
}

# Helper function for Get-SvtBackup when the -Sort parameter is specified. The function returns the property name
# expected by the REST API. The REST API accepts a single property name to sort on. Not all accepted property names
# are implemented here - only the ones deemed useful.
function Get-SvtSortString {
    [CmdletBinding()]
    param (
        # Parameter validation is performed by Get-SvtBackup, no need here
        [Parameter(Mandatory)]
        [System.String]$Sort
    )

    $ValidProperty = @{
        VmName        = 'virtual_machine_name'
        BackupName    = 'name'
        BackupSize    = 'size'
        CreateDate    = 'created_at'
        ExpiryDate    = 'expiration_time'
        ClusterName   = 'omnistack_cluster_name'
        DatastoreName = 'datastore_name'
    }

    # return the value that matches the specified sort string
    Write-Output $ValidProperty.$Sort
}

# Helper function used by Get/New/Copy-SvtBackup and New/Update-SvtPolicyRule to return the backup
# destination. This must be a cluster or an external store. Otherwise throw an error.
Function Get-SvtBackupDestination {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('Name')]
        [System.String[]]$DestinationName
    )

    [bool]$FoundCluster = $false
    [bool]$FoundExternalStore = $false
    [array]$DestinationNotFound = @()
    [array]$ReturnObject = @()

    foreach ($Destination in $DestinationName) {
        try {
            $Dest = Get-SvtCluster -Name $Destination -ErrorAction Stop
            if ($FoundExternalStore) {
                throw 'FoundMultipleDestinationTypes'
            }
            else {
                Write-Verbose "$($Dest.ClusterName) is a SimpliVity Cluster"
                $FoundCluster = $true
                $DestObject = @{
                    Type = 'Cluster'
                    Name = $Dest.ClusterName  #correct case
                    Id   = $Dest.ClusterId
                }
                $ReturnObject += $DestObject
                continue
            }
        }
        catch {
            if ($_.Exception.Message -eq 'FoundMultipleDestinationTypes') {
                throw 'Backup destinations must be of type cluster or external store, not both'
            }
            else {
                # Get-SvtCluster must have failed. Try External Store
            }
        }

        try {
            $Dest = Get-SvtExternalStore -Name $Destination -ErrorAction Stop
            if ($FoundCluster) {
                throw 'FoundMultipleDestinationTypes'
            }
            else {
                Write-Verbose "$($Dest.ExternalStoreName) is an external store"
                $FoundExternalStore = $true
                $DestObject = @{
                    Type = 'ExternalStore'
                    Name = $Dest.ExternalStoreName
                    Id   = $Dest.ExternalStoreName
                }
                $ReturnObject += $DestObject
            }
        }
        catch {
            if ($_.Exception.Message -eq 'FoundMultipleDestinationTypes') {
                throw 'Backup destinations must be of type cluster or external store, not both'
            }
            else {
                $DestinationNotFound += $Destination
            }
        }
    } #end foreach
    if ($ReturnObject) {
        if ($DestinationNotFound) {
            $Message = "Specified destination name(s) not found: $($DestinationNotFound -join ', ')"
            Write-Warning $Message
        }
        $ReturnObject | Sort-Object | Select-Object -Unique
    }
    else {
        throw 'Invalid backup destination name specified. Enter a valid cluster or external store name.'
    }
}

# Helper function for Invoke-RestMethod to handle all REST requests and errors in one place.
# This cmdlet either returns a HPE.SimpliVity.Task object if the REST API response is a task object,
# or otherwise the raw JSON for the calling function to deal with.

function Invoke-SvtRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [System.Object]$Uri,

        [Parameter(Mandatory, Position = 1)]
        [System.Collections.IDictionary]$Header,

        [Parameter(Mandatory, Position = 2)]
        [ValidateSet('get', 'post', 'delete', 'put')]
        [System.String]$Method,

        [Parameter(Position = 3)]
        [System.Object]$Body
    )

    [System.int32]$Retrycount = 0
    [bool]$LoopEnd = $false

    do {
        try {
            #Write-Verbose "$($PSBoundParameters | ConvertTo-Json)"
            if ($PSEdition -eq 'Core' -and -not $SvtConnection.SignedCertificate) {
                # PowerShell Core without a signed cert
                $Response = Invoke-RestMethod @PSBoundParameters -SkipCertificateCheck
            }
            else {
                # Windows PowerShell (with or without a signed cert) or PowerShell Core with a signed cert
                $Response = Invoke-RestMethod @PSBoundParameters
            }
            $LoopEnd = $true
        }
        catch [System.Management.Automation.RuntimeException] {
            if ($_.Exception.Message -match 'Unauthorized') {
                if ($Retrycount -ge 3) {
                    # Exit after 3 retries
                    throw 'Runtime error: Session expired and could not reconnect'
                }
                else {
                    $Retrycount += 1
                    Write-Verbose 'Session expired, reconnecting...'
                    $SVA = $SvtConnection.VA -replace 'https://', ''
                    $Retry = Connect-Svt -VirtualAppliance $SVA -Credential $SvtConnection.Credential

                    # Update the json header authorisation with the new token for the retry,
                    # not the entire header; this breaks subsequent POST calls.
                    $Header.Authorization = "Bearer $($Retry.Token)"
                }
            }
            elseif ($_.Exception.Message -match 'The hostname could not be parsed') {
                throw 'Runtime error: You must first log in using Connect-Svt'
            }
            else {
                # Return the embedded error message in the body of the response from the API
                throw "Runtime error: $(Get-SvtError($_))"
                #throw "Runtime error: $($_.Exception.Message)"
            }
        }
        catch {
            throw "An unexpected error occurred: $($_.Exception.Message)"
        }
    }
    until ($LoopEnd -eq $true)

    # If the JSON output is a task, convert it to a custom object of type 'HPE.SimpliVity.Task' and pass this
    # back to the calling cmdlet.
    # Note: $Response.task is incorrectly true with /api/omnistack_clusters/throughput, so added a check for this.
    if ($Response.task -and $URI -notmatch '/api/omnistack_clusters/throughput') {
        $Response.task | ForEach-Object {
            [PSCustomObject]@{
                PSTypeName      = 'HPE.SimpliVity.Task'
                StartTime       = ConvertFrom-SvtUtc -Date $_.start_time
                AffectedObjects = $_.affected_objects
                OwnerId         = $_.owner_id
                DestinationId   = $_.destination_id
                Name            = $_.name
                EndTime         = ConvertFrom-SvtUtc -Date $_.end_time
                ErrorCode       = $_.error_code
                ErrorMessage    = $_.error_message
                State           = $_.state
                TaskId          = $_.id
                Type            = $_.type
                PercentComplete = $_.percent_complete
            }
        }
    }
    else {
        # For all other object types, return the raw JSON output for the calling cmdlet to deal with
        $Response
    }
}

<#
.SYNOPSIS
    Show information about tasks that are currently executing or have finished executing in an HPE SimpliVity environment
.DESCRIPTION
    Performing most Post/Delete calls to the SimpliVity REST API will generate task objects as output.
    Whilst these task objects are immediately returned, the task themselves will change state over time.
    For example, when a Clone VM task completes, its state changes from IN_PROGRESS to COMPLETED.

    All cmdlets that return a JSON 'task' object, (e.g. New-SvtBackup and New-SvtClone) will output custom task
    objects of type HPE.SimpliVity.Task and can then be used as input here to find out if the task completed
    successfully. You can either specify the Task ID from the cmdlet output or, more usefully, use $SvtTask.
    This is a global variable that all 'task producing' HPE SimpliVity cmdlets create. $SvtTask is
    overwritten each time one of these cmdlets is executed.
.PARAMETER Task
    The task object(s). Use the global variable $SvtTask which is generated from a 'task producing'
    HPE SimpliVity cmdlet, like New-SvtBackup, New-SvtClone and Move-SvtVm.
.PARAMETER Id
    Specify a valid task ID
.INPUTS
    HPE.SimpliVity.Task
.OUTPUTS
    HPE.SimpliVity.Task
.EXAMPLE
    PS C:\> Get-SvtTask

    Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates
    a SimpliVity resource
.EXAMPLE
    PS C:\> New-SvtBackup -VmName MyVm
    PS C:\> Get-SvtTask

    Show the current state of the task executed from the New-SvtBackup cmdlet.
.EXAMPLE
    PS C:\> New-SvtClone Win2019-01 NewWin2019-01
    PS C:\> Get-SvtTask | Format-List

    The first command clones the specified VM.
    The second command monitors the progress of the clone task, showing all the task properties.
.EXAMPLE
    PS C:\> Get-SvtTask -ID d7ef1442-2633-...-a03e69ae24a6

    Displays the progress of the specified task ID. This command is useful when using the Web console to
    test REST API calls
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtTask.md
#>
function Get-SvtTask {
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeLine = $true, ParameterSetName = 'ByObject')]
        [System.Object]$Task = $SvtTask,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [String]$Id
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }
        if ($PSBoundParameters.ContainsKey('Id')) {
            $Task = @{ TaskId = $Id }
        }
        Write-Verbose "$($Task | ConvertTo-Json)"
    }

    process {
        foreach ($ThisTask in $Task) {
            $Uri = $global:SvtConnection.VA + '/api/tasks/' + $ThisTask.TaskId

            try {
                Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
    }
}



<#
.SYNOPSIS
    Connect to a HPE SimpliVity Virtual Appliance (SVA) or Managed Virtual Appliance (MVA)
.DESCRIPTION
    To access the SimpliVity REST API, you need to request an authentication token by issuing a request
    using the OAuth authentication method. Once obtained, you can pass the resulting access token via the
    HTTP header using an Authorisation Bearer token.

    The access token is stored in a global variable called $SvtConnection and is accessible to all HPESimpliVity
    cmdlets in the PowerShell session. Note that the access token times out after 10 minutes of inactivity. However,
    the HPESimpliVity module will automatically recreate a new token using cached credentials.
.PARAMETER VirtualAppliance
    The Fully Qualified Domain Name (FQDN) or IP address of any SimpliVity Virtual Appliance or Managed Virtual
    Appliance in the SimpliVity Federation.
.PARAMETER Credential
    User generated credential as System.Management.Automation.PSCredential. Use the Get-Credential
    PowerShell cmdlet to create the credential. This can optionally be imported from a file in cases where
    you are invoking non-interactively. E.g. shutting down the SVAs from a script invoked by UPS software.
.PARAMETER SignedCert
    Requires a trusted certificate to enable TLS1.2. By default, the cmdlet allows untrusted certificates with
    HTTPS connections. This is, most commonly, a self-signed certificate. Alternatively it could be a
    certificate issued from an untrusted certificate authority, such as an internal CA.
.INPUTS
    System.String
    System.Management.Automation.PSCredential
.OUTPUTS
    System.Management.Automation.PSCustomObject
.EXAMPLE
    PS C:\> Connect-Svt -VirtualAppliance <FQDN or IP Address of SVA or MVA>

    This will securely prompt you for credentials
.EXAMPLE
    PS C:\> $Cred = Get-Credential -Message 'Enter Credentials'
    PS C:\> Connect-Svt -VA 10.1.1.16 -Credential $Cred

    Create the credential first, then pass it as a parameter.
.EXAMPLE
    PS C:\> $CredFile = "$((Get-Location).Path)\SvaCred.XML"
    PS C:\> Get-Credential -Credential '<username@domain>'| Export-CLIXML $CredFile

    Another way is to store the credential in a file (as above), then connect to the SVA using:
    PS C:\> Connect-Svt -VA <FQDN or IP Address of SVA or MVA> -Credential $(Import-CLIXML $CredFile)

    or:
    PS C:\> $Cred = Import-CLIXML $CredFile
    PS C:\> Connect-Svt -VA <FQDN or IP Address of SVA or MVA> -Credential $Cred

    This method is useful in non-interactive sessions. Once the file is created, run the Connect-Svt
    command to connect and reconnect to the SVA, as required.
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Connect-Svt.md
#>
function Connect-Svt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('VA', 'SVA', 'MVA', 'OVC')]
        [System.String]$VirtualAppliance,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Management.Automation.PSCredential]$Credential,

        [Switch]$SignedCert
    )

    $Header = @{
        'Authorization' = 'Basic ' +
        [System.Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes('simplivity:'))

        'Accept'        = 'application/json'
    }
    $Uri = 'https://' + $VirtualAppliance + '/api/oauth/token'

    if ($SignedCert) {
        # User has specified -SignedCert, so the SVA/MVA must have a certificate which is trusted by the client
    }
    else {
        # Effectively bypass TLS by trusting all certificates. Works with untrusted, self-signed certs and is the
        # default. Ideally, customers should install trusted certificates, but this is rarely implemented.
        if ($PSEdition -eq 'Core') {
            # With PowerShell Core, Invoke-RestMethod supports -SkipCertificateCheck. The global $SvtConnection
            # variable has a 'SignedCertificate' property set here, used by Invoke-SvtRestMethod.
        }
        else {
            # With Windows PowerShell, use .Net ServicePointManager to create an object of type TrustAllCertsPolicy
            if ( -not ('TrustAllCertsPolicy' -as [type])) {
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
        }
    }

    # Two ways to securely authenticate are available - via an existing credential object which is previously
    # created and passed in, or prompt for a credential
    if ($Credential) {
        $SecCred = $Credential
    }
    else {
        $SecCred = Get-Credential -Message 'Enter credentials with authorisation to login ' +
        'to your SimpliVity Virtual Appliance (e.g. administrator@vsphere.local)'
    }

    $Body = @{
        'username'   = $SecCred.Username
        'password'   = $SecCred.GetNetworkCredential().Password
        'grant_type' = 'password'
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $global:SvtConnection = [PSCustomObject]@{
        VA                = "https://$VirtualAppliance"
        OVC               = "https://$VirtualAppliance"
        Credential        = $SecCred
        Token             = $Response.access_token
        UpdateTime        = $Response.updated_at
        Expiration        = $Response.expires_in
        SignedCertificate = $SignedCert.IsPresent
    }
    # Return connection object to the pipeline. Used by all other HPESimpliVity cmdlets.
    $global:SvtConnection

    # Finally, create the global variable SvtHost, if it doesn't exist for this session.
    if (-not $global:SvtHost) {
        Get-SvtHost | Out-Null
    }
}

<#
.SYNOPSIS
    Get the REST API version and SVTFS version of the HPE SimpliVity environment
.DESCRIPTION
    Get the REST API version and SVTFS version of the HPE SimpliVity environment
.INPUTS
    None
.OUTPUTS
    System.Management.Automation.PSCustomObject
.EXAMPLE
    PS C:\> Get-SvtVersion

    Shows version information for the REST API and SVTFS. It also shows whether you are
    connecting to an Omnistack Virtual Appliance (OVA) or a Managed Virtual Appliance (MVA).
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVersion.md
#>
function Get-SvtVersion {
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }
    $Uri = $global:SvtConnection.VA + '/api/version'

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    if ($Response.SVTFS_Version) {
        $Appliance = 'SimpliVity Virtual Appliance'
    }
    else {
        $Appliance = 'Managed Virtual Appliance'
    }

    $Response | ForEach-Object {
        [PSCustomObject]@{
            'RestApiVersion'          = $_.REST_API_Version
            'SvtFsVersion'            = $_.SVTFS_Version
            'PowerShellModuleVersion' = $HPESimplivityVersion
            'VirtualControllerType'   = $Appliance
        }
    }
}

<#
.SYNOPSIS
    Display the performance information about the specified HPE SimpliVity resource(s)
.DESCRIPTION
    Displays the performance metrics for one of the following specified HPE SimpliVity resources:
        - Cluster
        - Host
        - VM

    In addition, output from the Get-SvtCluster, Get-Host and Get-SvtVm commands is accepted as input.
.PARAMETER SvtObject
    Used to accept input from the pipeline. Accepts HPESimpliVity objects with a specific type
.PARAMETER ClusterName
    Show performance metrics for the specified SimpliVity cluster(s)
.PARAMETER HostName
    Show performance metrics for the specified SimpliVity node(s)
.PARAMETER VmName
    Show performance metrics for the specified virtual machine(s) hosted on SimpliVity storage
.PARAMETER OffsetHour
    Show performance metrics starting from the specified offset (hours from now, default is now)
.PARAMETER Hour
    Show performance metrics for the specified number of hours (starting from OffsetHour)
.PARAMETER Resolution
    The resolution in seconds, minutes, hours or days
.PARAMETER Chart
    Create a chart instead of showing performance metrics. The chart file is saved to the current folder.
    One chart is created for each object (e.g. cluster, host or VM)
.PARAMETER ChartProperty
    Specify the properties (metrics) you'd like to see on the chart. By default all properties are shown
.EXAMPLE
    PS C:\> Get-SvtMetric -ClusterName Production

    Shows performance metrics about the specified cluster, using the default hour setting (24 hours) and
    resolution (every hour)
.EXAMPLE
    PS C:\> Get-SvtHost | Get-SvtMetric -Hour 1 -Resolution SECOND

    Shows performance metrics for all hosts in the federation, for every second of the last hour
.EXAMPLE
    PS C:\> Get-SvtVm | Where VmName -match "SQL" | Get-SvtMetric

    Show performance metrics for every VM that has "SQL" in its name
.EXAMPLE
    PS C:\> Get-SvtCluster -ClusterName DR | Get-SvtMetric -Hour 1440 -Resolution DAY

    Show daily performance metrics for the last two months for the specified cluster
.EXAMPLE
    PS C:\> Get-SvtVm Vm1,Vm2,Vm3 | Get-SvtMetric -Chart -Verbose

    Create chart(s) instead of showing the metric data. Chart files are created in the current folder.
    Use filtering when creating charts for virtual machines to avoid creating a lot of charts.
.EXAMPLE
    PS C:\> Get-SvtHost -Name MyHost | Get-SvtMetric -Chart | Foreach-Object {Invoke-Item $_}

    Create a metrics chart for the specified host and immediately display it. Note that Invoke-Item
    only works with image files when the Desktop Experience Feature is installed (may not be installed
    on some servers)
.EXAMPLE
    PS C:\> Get-SvtMetric -Cluster SvtCluster -Chart -ChartProperty IopsRead,IopsWrite

    Create a metrics chart for the specified cluster showing only the specified properties. By default
    the last day is shown (-Hour 24) with a resolution of MINUTE (-Resolution MINUTE).
.EXAMPLE
    PS C:\> Get-SvtMetric -Host server1 -Chart -OffsetHour 24

    Create a chart showing metric information from yesterday (or more correctly, a days worth of information
    prior to the last 24 hours).
.INPUTS
    System.String
    HPE.SimpliVity.Cluster
    HPE.SimpliVity.Host
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Metric
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtMetric.md
#>
function Get-SvtMetric {
    [CmdletBinding(DefaultParameterSetName = 'Host')]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Host')]
        [System.String[]]$HostName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Cluster')]
        [System.String[]]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'VirtualMachine')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ParameterSetName = 'SvtObject')]
        [System.Object]$SvtObject,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$OffsetHour = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.Int32]$Hour = 24,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'MINUTE',

        [Parameter(Mandatory = $false)]
        [Switch]$Chart,

        [Parameter(Mandatory = $false)]
        [ValidateSet('IopsRead', 'IopsWrite', 'LatencyRead', 'LatencyWrite', 'ThroughputRead', 'ThroughputWrite')]
        [System.String[]]$ChartProperty = ('IopsRead', 'IopsWrite', 'LatencyRead', 'LatencyWrite',
            'ThroughputRead', 'ThroughputWrite')
    )

    begin {
        #$VerbosePreference = 'Continue'
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }

        $Range = $Hour * 3600
        $Offset = $OffsetHour * 3600

        if ($Resolution -eq 'SECOND' -and $Range -gt 43200 ) {
            throw "Maximum range value for resolution $resolution is 12 hours"
        }
        elseif ($Resolution -eq 'MINUTE' -and $Range -gt 604800 ) {
            throw "Maximum range value for resolution $resolution is 168 hours (1 week)"
        }
        elseif ($Resolution -eq 'HOUR' -and $Range -gt 5184000 ) {
            throw "Maximum range value for resolution $resolution is 1,440 hours (2 months)"
        }
        elseif ($Resolution -eq 'DAY' -and $Range -gt 94608000 ) {
            throw "Maximum range value for resolution $resolution is 26,280 hours (3 years)"
        }

        if ($Resolution -eq 'SECOND' -and $Range -gt 7200 ) {
            $Message = 'Using the resolution of SECOND beyond a range of 2 hour can take a long time to complete'
            Write-Warning $Message
        }
        if ($Resolution -eq 'MINUTE' -and $Range -gt 86400 ) {
            $Message = 'Using the resolution of MINUTE beyond a range of 24 hours can take a long time to complete'
            Write-Warning $Message
        }
    }

    process {
        if ($PSBoundParameters.ContainsKey('SvtObject')) {
            $InputObject = $SvtObject
        }
        elseif ($PSBoundParameters.ContainsKey('ClusterName')) {
            $InputObject = $ClusterName
        }
        elseif ($PSBoundParameters.ContainsKey('HostName')) {
            $InputObject = $HostName
        }
        else {
            $InputObject = $VmName
        }

        foreach ($Item in $InputObject) {
            $TypeName = $Item | Get-Member | Select-Object -ExpandProperty TypeName -Unique
            if ($TypeName -eq 'HPE.SimpliVity.Cluster') {
                $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $Item.ClusterId + '/metrics'
                $ObjectName = $Item.ClusterName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.Host') {
                $Uri = $global:SvtConnection.VA + '/api/hosts/' + $Item.HostId + '/metrics'
                $ObjectName = $Item.HostName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.VirtualMachine') {
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $Item.VmId + '/metrics'
                $ObjectName = $Item.VmName
            }
            elseif ($PSBoundParameters.ContainsKey('VmName')) {
                try {
                    $VmId = Get-SvtVm -VmName $Item -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmId + '/metrics'
                    $ObjectName = $Item
                    $TypeName = 'HPE.SimpliVity.VirtualMachine'
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            elseif ($PSBoundParameters.ContainsKey('HostName')) {
                try {
                    $HostName = Resolve-SvtFullHostName -HostName $Item -ErrorAction Stop

                    $HostId = $global:SvtHost | Where-Object Hostname -eq $HostName |
                    Select-Object -ExpandProperty HostId

                    $Uri = $global:SvtConnection.VA + '/api/hosts/' + $HostId + '/metrics'
                    $ObjectName = $Item
                    $TypeName = 'HPE.SimpliVity.Host'
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                # This is deliberately a catchall. $SvtObject could be passed in as a string, e.g.
                # 'Cluster01' | Get-SvtMetric
                try {
                    $Cluster = Get-SvtCluster -ClusterName $Item -ErrorAction Stop
                    $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $Cluster.ClusterId + '/metrics'
                    $ObjectName = $Cluster.ClusterName
                    $TypeName = 'HPE.SimpliVity.Cluster'
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            Write-verbose "Object name is $ObjectName ($TypeName)"

            try {
                $Uri = $Uri + "?time_offset=$Offset&range=$Range&resolution=$Resolution"
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This returns each Metric with a date and some values
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = (Get-Culture).TextInfo.ToTitleCase($_.name)
                $_.data_points | ForEach-Object {
                    [PSCustomObject] @{
                        Name  = $MetricName
                        Date  = ConvertFrom-SvtUtc -Date $_.date
                        Read  = $_.reads
                        Write = $_.writes
                    }
                }
            }

            # Transpose the custom object to return each date with read and write for each metric
            # NOTE: PowerShell Core displays grouped items out of order, so sort again by Name
            $MetricObject = $CustomObject | Sort-Object -Property { $_.Date -as [datetime] } |
            Group-Object -Property Date | Sort-Object -Property { $_.Name -as [datetime] } |
            ForEach-Object {
                $Property = [ordered]@{
                    PSTypeName = 'HPE.SimpliVity.Metric'
                    Date       = $_.Name
                }

                [string]$PrevName = ''
                $_.Group | Foreach-object {
                    # We expect one instance each of Iops, Latency and Throughput per date.
                    # But sometimes the API returns more. Attempting to create a key that already
                    # exists generates a non-terminating error so, check for duplicates.
                    if ($_.name -ne $PrevName) {
                        $Property += [ordered]@{
                            "$($_.Name)Read"  = $_.Read
                            "$($_.Name)Write" = $_.Write
                        }
                    }
                    $PrevName = $_.Name
                }

                $Property += [ordered]@{
                    ObjectType = $TypeName
                    ObjectName = $ObjectName
                }
                New-Object -TypeName PSObject -Property $Property
            }

            if ($PSBoundParameters.ContainsKey('Chart')) {
                Get-SvtMetricChart -Metric $MetricObject -ChartProperty $ChartProperty
            }
            else {
                $MetricObject
            }
        } #end for
    } #end process
}

# Helper function for Get-SvtMetric
function Get-SvtMetricChart {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Metric,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String[]]$ChartProperty
    )

    # add the required properties to those specified by the user and make sure each property is unique
    $ChartProperty += 'Date', 'ObjectType', 'ObjectName'
    $ChartProperty = $ChartProperty | Sort-Object | Select-Object -Unique

    # get the object type - e.g. cluster, host or VM
    $TypeName = $Metric | Get-Member | Select-Object -ExpandProperty TypeName -Unique

    # get the names of each object passed in, e.g. host names
    $ObjectList = $Metric.ObjectName | Select-Object -Unique

    # Path and datestamp are used for chart filename(s)
    $Path = Get-Location
    $DateStamp = Get-Date -Format 'yyMMddhhmmss'
    $Culture = Get-Culture
    $StartDate = $Metric | Select-Object -First 1 -ExpandProperty Date
    $EndDate = $Metric | Select-Object -Last 1 -ExpandProperty Date
    $ChartLabelFont = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 8
    $ChartTitleFont = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 12
    $Logo = (Split-Path -parent (Get-Module HPESimpliVity | Select-Object -First 1).Path) + '\hpe.png'

    # define an object to determine the best interval on the Y axis, given a maximum value
    $YMax = (0, 2500, 5000, 10000, 20000, 40000, 80000, 160000, 320000, 640000, 1280000, 2560000, 5120000, 10240000, 20480000)
    $YInterval = (100, 200, 400, 600, 1000, 5000, 10000, 15000, 20000, 50000, 75000, 100000, 250000, 400000, 1000000)
    $YAxis = 0..14 | ForEach-Object {
        [PSCustomObject]@{
            Maximum  = $YMax[$_]
            Interval = $YInterval[$_]
        }
    }

    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    foreach ($Instance in $ObjectList) {
        $DataSource = $Metric | Where-Object ObjectName -eq $Instance | Select-Object $ChartProperty
        $DataPoint = $DataSource | Measure-Object | Select-Object -ExpandProperty Count

        # create chart object
        $Chart1 = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
        $Chart1.Width = 1200
        $Chart1.Height = 600
        $Chart1.BackColor = [System.Drawing.Color]::WhiteSmoke

        # add the HPE logo
        $Image = New-Object System.Windows.Forms.DataVisualization.Charting.ImageAnnotation
        $Image.X = 85
        $Image.Y = 85
        $Image.Image = $Logo
        $Chart1.Annotations.Add($Image)

        # add a legend to the chart
        $Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
        $Legend.name = 'Legend1'
        $Chart1.Legends.Add($Legend)

        # add chart title. Shortname is also used for the chart filename
        try {
            $ShortName = ([IPaddress]$Instance).IPAddressToString
        }
        catch {
            # the object name is not an IP address
            $ShortName = $Instance -split '\.' | Select-Object -First 1
        }
        $null = $Chart1.Titles.Add("$($TypeName): $ShortName - Metrics from $StartDate to $EndDate")
        $Chart1.Titles[0].Font = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 16
        $Chart1.Titles[0].Alignment = 'topLeft'

        # add chart area, axistype is required to create primary and secondary YAxis
        $AxisEnabled = New-Object System.Windows.Forms.DataVisualization.Charting.AxisEnabled
        $AxisType = New-Object System.Windows.Forms.DataVisualization.Charting.AxisType
        $Area1 = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Area1.Name = 'ChartArea1'
        $Area1.AxisX.Title = 'Date'
        $Area1.AxisX.TitleFont = $ChartTitleFont
        $Area1.AxisX.LabelStyle.Font = $ChartLabelFont
        $Area1.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray

        # show a maximum of 24 labels on the XAxis
        $Interval = [math]::Round($DataPoint / 24)
        if ($Interval -lt 1) {
            $Area1.AxisX.Interval = 1
        }
        else {
            $Area1.AxisX.Interval = $Interval
        }

        # reduce line weight for charts with long time ranges
        if ($Interval -gt 30) {
            $BorderWidth = 1
        }
        else {
            $BorderWidth = 2
        }

        # Kill 2 birds. Determine if any of the properties measured on the primary Y-axis are required and if so,
        # collect the values so the maximum value can be found
        $AxisY1Data = @()
        if ('IopsRead' -in $ChartProperty) { $AxisY1Data += $DataSource | Select-Object -ExpandProperty IopsRead }
        if ('IopsWrite' -in $ChartProperty) { $AxisY1Data += $DataSource | Select-Object -ExpandProperty IopsWrite }
        if ('LatencyRead' -in $ChartProperty) { $AxisY1Data += $DataSource | Select-Object -ExpandProperty LatencyRead }
        if ('LatencyWrite' -in $ChartProperty) { $AxisY1Data += $DataSource | Select-Object -ExpandProperty LatencyWrite }

        if ($AxisY1Data) {
            # At least one of the properties measured on the primary Y-axis are present, so show labels
            $Area1.AxisY.Title = 'IOPS and Latency (milliseconds)'
            $Area1.AxisY.TitleFont = $ChartTitleFont
            $Area1.AxisY.LabelStyle.Font = $ChartLabelFont
            $Area1.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray

            # Determine an appropriate interval on the primary Y-axis, based on the maximum value
            $Max = $AxisY1Data | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            $YAxis | ForEach-Object {
                if ($Max -gt $_.Maximum) {
                    $Area1.AxisY.Interval = $_.Interval
                }
            }
        }

        if ($ChartProperty -match 'Throughput') {
            # At least one property measured on the secondary Y-axis is present, so show labels
            $Area1.AxisY2.Title = 'Throughput (Mbps)'
            $Area1.AxisY2.TitleFont = $ChartTitleFont
            $Area1.AxisY2.LabelStyle.Font = $ChartLabelFont
            If ($AxisY1Data) {
                # The primary Y-axis is also being displayed, so don't show grid lines for the secondary Y-axis
                $Area1.AxisY2.MajorGrid.LineColor = [System.Drawing.Color]::Transparent
                $Area1.AxisY2.MajorGrid.Enabled = $false
            }
            else {
                $Area1.AxisY2.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
                $Area1.AxisY2.MajorGrid.Enabled = $true
            }
            $Area1.AxisY2.Enabled = $AxisEnabled::true
            # Not setting a specific interval on the secondary Y-axis
        }

        # add area to chart
        $Chart1.ChartAreas.Add($Area1)
        $Chart1.ChartAreas['ChartArea1'].AxisY.LabelStyle.Angle = 0
        $Chart1.ChartAreas['ChartArea1'].AxisX.LabelStyle.Angle = -45

        # data series
        if ('IopsRead' -in $ChartProperty) {
            $null = $Chart1.Series.Add('IopsRead')
            $Chart1.Series['IopsRead'].YAxisType = $AxisType::Primary
            $Chart1.Series['IopsRead'].ChartType = 'Line'
            $Chart1.Series['IopsRead'].BorderWidth = $BorderWidth
            $Chart1.Series['IopsRead'].IsVisibleInLegend = $true
            $Chart1.Series['IopsRead'].ChartArea = 'ChartArea1'
            $Chart1.Series['IopsRead'].Legend = 'Legend1'
            $Chart1.Series['IopsRead'].Color = [System.Drawing.Color]::FromArgb(118, 48, 234) #7630EA - HPE Medium Purple
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['IopsRead'].Points.addxy($Date, $_.IopsRead)
            }
        }

        # data series
        if ('IopsWrite' -in $ChartProperty) {
            $null = $Chart1.Series.Add('IopsWrite')
            $Chart1.Series['IopsWrite'].YAxisType = $AxisType::Primary
            $Chart1.Series['IopsWrite'].ChartType = 'Line'
            $Chart1.Series['IopsWrite'].BorderWidth = $BorderWidth
            $Chart1.Series['IopsWrite'].IsVisibleInLegend = $true
            $Chart1.Series['IopsWrite'].ChartArea = 'ChartArea1'
            $Chart1.Series['IopsWrite'].Legend = 'Legend1'
            $Chart1.Series['IopsWrite'].Color = [System.Drawing.Color]::FromArgb(193, 64, 255) #C140FF - HPE Light Purple
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['IopsWrite'].Points.addxy($Date, $_.IopsWrite)
            }
        }

        # data series
        if ('LatencyRead' -in $ChartProperty) {
            $null = $Chart1.Series.Add('LatencyRead')
            $Chart1.Series['LatencyRead'].YAxisType = $AxisType::Primary
            $Chart1.Series['LatencyRead'].ChartType = 'Line'
            $Chart1.Series['LatencyRead'].BorderWidth = $BorderWidth
            $Chart1.Series['LatencyRead'].IsVisibleInLegend = $true
            $Chart1.Series['LatencyRead'].ChartArea = 'ChartArea1'
            $Chart1.Series['LatencyRead'].Legend = 'Legend1'
            $Chart1.Series['LatencyRead'].Color = [System.Drawing.Color]::FromArgb(254, 201, 1) #FEC901 - HPE Yellow
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['LatencyRead'].Points.addxy($Date, $_.LatencyRead)
            }
        }

        # data series
        if ('LatencyWrite' -in $ChartProperty) {
            $null = $Chart1.Series.Add('LatencyWrite')
            $Chart1.Series['LatencyWrite'].YAxisType = $AxisType::Primary
            $Chart1.Series['LatencyWrite'].ChartType = 'Line'
            $Chart1.Series['LatencyWrite'].BorderWidth = $BorderWidth
            $Chart1.Series['LatencyWrite'].IsVisibleInLegend = $true
            $Chart1.Series['LatencyWrite'].ChartArea = 'ChartArea1'
            $Chart1.Series['LatencyWrite'].Legend = 'Legend1'
            $Chart1.Series['LatencyWrite'].Color = [System.Drawing.Color]::FromArgb(255, 131, 0) #FF8300 - Aruba Orange
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['LatencyWrite'].Points.addxy($Date, $_.LatencyWrite)
            }
        }

        # data series
        if ('ThroughputRead' -in $ChartProperty) {
            $null = $Chart1.Series.Add('ThroughputRead')
            $Chart1.Series['ThroughputRead'].YAxisType = $AxisType::Secondary
            $Chart1.Series['ThroughputRead'].ChartType = 'Line'
            $Chart1.Series['ThroughputRead'].BorderWidth = $BorderWidth
            $Chart1.Series['ThroughputRead'].IsVisibleInLegend = $true
            $Chart1.Series['ThroughputRead'].ChartArea = 'ChartArea1'
            $Chart1.Series['ThroughputRead'].Legend = 'Legend1'
            $Chart1.Series['ThroughputRead'].Color = [System.Drawing.Color]::FromArgb(13, 82, 101) #0D5265 - HPE Dark Blue
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['ThroughputRead'].Points.addxy($Date, ($_.ThroughputRead / 1024 / 1024))
            }
        }

        # data series
        if ('ThroughputWrite' -in $ChartProperty) {
            $null = $Chart1.Series.Add('ThroughputWrite')
            $Chart1.Series['ThroughputWrite'].YAxisType = $AxisType::Secondary
            $Chart1.Series['ThroughputWrite'].ChartType = 'Line'
            $Chart1.Series['ThroughputWrite'].BorderWidth = $BorderWidth
            $Chart1.Series['ThroughputWrite'].IsVisibleInLegend = $true
            $Chart1.Series['ThroughputWrite'].ChartArea = 'ChartArea1'
            $Chart1.Series['ThroughputWrite'].Legend = 'Legend1'
            $Chart1.Series['ThroughputWrite'].Color = [System.Drawing.Color]::FromArgb(50, 218, 200) #32DAC8 - HPE Medium Blue
            $DataSource | ForEach-Object {
                $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
                $null = $Chart1.Series['ThroughputWrite'].Points.addxy($Date, ($_.ThroughputWrite / 1024 / 1024))
            }
        }

        # save chart and send filename to the pipeline
        try {
            $Chart1.SaveImage("$Path\SvtMetric-$ShortName-$DateStamp.png", 'png')
            Get-ChildItem "$Path\SvtMetric-$ShortName-$DateStamp.png" -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
            #throw "Could not create $Path\SvtMetric-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SvtCapacity
function Get-SvtCapacityChart {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Capacity
    )

    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    $Path = Get-Location
    $ChartLabelFont = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 10
    $ChartTitleFont = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 13
    $DateStamp = Get-Date -Format 'yyMMddhhmmss'
    $Logo = (Split-Path -parent (Get-Module HPESimpliVity).Path | Select-Object -First 1) + '\hpe.png'

    $ObjectList = $Capacity.HostName | Select-Object -Unique
    foreach ($Instance in $ObjectList) {
        $Cap = $Capacity | Where-Object HostName -eq $Instance | Select-Object -Last 1

        $DataSource = [ordered]@{
            'Allocated Capacity'          = $Cap.AllocatedCapacity / 1GB
            'Used Capacity'               = $Cap.UsedCapacity / 1GB
            'Free Space'                  = $Cap.FreeSpace / 1GB
            'Used Logical Capacity'       = $Cap.UsedLogicalCapacity / 1GB
            'Capacity Savings'            = $Cap.CapacitySavings / 1GB
            'Local Backup Capacity'       = $Cap.LocalBackupCapacity / 1GB
            'Remote Backup Capacity'      = $Cap.RemoteBackupCapacity / 1GB
            'Stored Compressed Data'      = $Cap.StoredCompressedData / 1GB
            'Stored Uncompressed Data'    = $Cap.StoredUncompressedData / 1GB
            'Stored Virtual Machine Data' = $Cap.StoredVirtualMachineData / 1GB
        }

        # create chart object
        $Chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
        $Chart1.Width = 1200
        $Chart1.Height = 600
        $Chart1.BackColor = [System.Drawing.Color]::WhiteSmoke

        # add HPE logo
        $Image = New-Object System.Windows.Forms.DataVisualization.Charting.ImageAnnotation
        $Image.X = 85
        $Image.Y = 85
        $Image.Image = $Logo
        $Chart1.Annotations.Add($Image)

        # add title, shortname is also used for filename(s)
        try {
            $ShortName = ([ipaddress]$Instance).IPAddressToString
        }
        catch {
            $ShortName = $Instance -split '\.' | Select-Object -First 1
        }
        $null = $Chart1.Titles.Add("HPE.SimpliVity.Host: $ShortName - Capacity from $($Cap.Date)")
        $Chart1.Titles[0].Font = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 16
        $Chart1.Titles[0].Alignment = 'topLeft'

        # create chart area
        $Area1 = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Area3DStyle = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea3DStyle
        $Area3DStyle.Enable3D = $true
        $Area3DStyle.LightStyle = 1
        $Area3DStyle.Inclination = 20
        $Area3DStyle.Perspective = 0

        $Area1 = $Chart1.ChartAreas.Add('ChartArea1')
        $Area1.Area3DStyle = $Area3DStyle

        $Area1.AxisY.Title = 'Size (GB)'
        $Area1.AxisY.TitleFont = $ChartTitleFont
        $Area1.AxisY.LabelStyle.Font = $ChartLabelFont
        $Area1.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
        $Area1.AxisX.MajorGrid.Enabled = $false
        $Area1.AxisX.MajorTickMark.Enabled = $true
        $Area1.AxisX.LabelStyle.Enabled = $true
        $Area1.BackColor = [System.Drawing.Color]::White

        $Max = $DataSource.Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
        if ($Max -lt 10000) {
            $Area1.AxisY.Interval = 1000
        }
        elseif ($Max -lt 20000) {
            $Area1.AxisY.Interval = 5000
        }
        else {
            $Area1.AxisY.Interval = 20000
        }
        $Area1.AxisX.Interval = 1
        $Chart1.ChartAreas['ChartArea1'].AxisY.LabelStyle.Angle = 0
        $Chart1.ChartAreas['ChartArea1'].AxisX.LabelStyle.Angle = -35

        # add series
        $null = $Chart1.Series.Add('Data')
        $Chart1.Series['Data'].Points.DataBindXY($DataSource.Keys, $DataSource.Values)
        $Chart1.Series['Data'].Color = [System.Drawing.Color]::FromArgb(1, 169, 130) #01A982 - HPE Green

        # save chart
        try {
            $Chart1.SaveImage("$Path\SvtCapacity-$ShortName-$DateStamp.png", 'png')
            Get-ChildItem "$Path\SvtCapacity-$ShortName-$DateStamp.png" -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
            #throw "Could not create $Path\SvtCapacity-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SvtDisk
# Notes: This method works quite well when all the disks are the same capacity. The 380 H introduces a bit
# of a problem. As long as the disks are sorted by slot number (i.e. the first disk will always be an SSD),
# then the 380H disk capacity will be 1.92TB - the first disk is used to confirm the server type. This
# method may break if additional models continue to be added.
# G (all flash) and H are both software optimized models.
function Get-SvtModel {
    $Model = (
        '325',
        '325',
        '2600',
        '380',
        '380',
        '380',
        '380',
        '380',
        '380 Gen10 H',
        '380 Gen10 H',
        '380 Gen10 G',
        '380 Gen10 G',
        '380 Gen10 G',
        '380 Gen10 G'
    )
    $DiskCount = (4, 6, 6, 5, 5, 9, 12, 12, 12, 24, 6, 8, 12, 16)
    $DiskCapacity = (2, 2, 2, 1, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2)
    $Kit = (
        '  4-8TB - SVT325 Extra Small',
        ' 7-15TB - SVT325 Small',
        ' 7-15TB - SVT2600',
        '  3-6TB - SVT380Gen10 Extra Small', # 960GB disk ~ 1TB
        ' 6-12TB - SVT380Gen10 Small',
        '12-25TB - SVT380Gen10 Medium',
        '20-40TB - SVT380Gen10 Large',
        '40-80TB - SVT380Gen10 Extra Large', # 3.8TB disk ~ 4TB
        '20-40TB - SVT380Gen10H (LFF)', # 4X1.92 SSD + 8X4TB HDD = 12 disks (Backup/Archive)
        '25-50TB - SVT380Gen10H (SFF)', # 4X1.92 SSD + 20X1.2TB HDD = 24 disks (General Purpose)
        ' 8-16TB - SVT380Gen10G x6',
        ' 7-15TB - SVT380Gen10G x8',
        '15-30TB - SVT380Gen10G x12',
        '20-40TB - SVT380Gen10G x16'
    )

    # return a custom object
    0..13 | ForEach-Object {
        [PSCustomObject]@{
            Model        = $Model[$_]
            DiskCount    = $DiskCount[$_]
            DiskCapacity = $DiskCapacity[$_]
            StorageKit   = $Kit[$_]
        }
    }
}

# Helper function for New-SvtPolicyRule, Remove-SvtPolicyRule, Update-SvtPolicyRule and Set-SvtVm
function Get-SvtImpactReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Response
    )
    $TextInfo = (Get-Culture).TextInfo
    foreach ($Attribute in $Response.schedule_before_change.PSObject.Properties.Name) {
        [PSCustomObject]@{
            'Attribute'    = $TextInfo.ToTitleCase($Attribute) -replace '_', ''
            'BeforeChange' = $Response.schedule_before_change.$Attribute
            'AfterChange'  = $Response.schedule_after_change.$Attribute
        }
    }
}

#endregion Utility

#region Backup

<#
.SYNOPSIS
    Display information about HPE SimpliVity backups.
.DESCRIPTION
    Show backup information from the HPE SimpliVity Federation. Without any parameters, SimpliVity backups from
    the last 24 hours are shown, but this can be overridden by specifying the -Hour parameter.

    By default the limit is set to show up to 500 backups, as per the HPE recommended value. This can be set to a
    maximum of 3000 backups using -Limit.

    If -Date is used, it will override -CreatedAfter, -CreatedBefore and -Hour. The other date related parameters
    all override -Hour, if specified.

    -All will display all backups, regardless of limit. Be careful, this command will take a long time to
    complete because it returns ALL backups. It does this by calling the SimpliVity API multiple times (using
    an offset value of 3000). It is recommended to use other parameters with the -All parameter to limit the output.

    The use of -Verbose is recommended because it shows information about what the command is doing. It also shows
    the total number of matching backups. If matching backups is higher than -Limit (500 by default), then you are
    not seeing all the matching backups.

    Multiple values can be used for most parameters, but only when connecting to a Managed Virtual Appliance.
    Multi-value parameters currently fail when connected to a SimpliVity Virtual Appliance. For this reason, using
    an MVA (centralized configuration) is highly recommended.
.PARAMETER VmName
    Show backups for the specified virtual machine(s). By default a limit of 500 backups are shown, but this can be
    increased to 3000 using -Limit, or removed using -All.
.PARAMETER ClusterName
    Show backups sourced from a specified HPE SimpliVity cluster name or names. By default a limit of 500 backups are
    shown.
.PARAMETER DatastoreName
    Show backups sourced from a specified SimpliVity datastore or datastores. By default a limit of 500 backups are
    shown.
.PARAMETER DestinationName
    Show backups located on the specified destination HPE SimpliVity cluster name or external datastore name.
    Multiple destinations can be specified, but they must all be of one type (i.e. cluster or external store)
    By default a limit of 500 backups are shown, but this can be increased.
.PARAMETER BackupId
    Show the backup with the specified backup ID only.
.PARAMETER BackupName
    Show backups with the specified backup name only.
.PARAMETER BackupState
    Show backups with the specified state. i.e. PROTECTED, FAILED or SAVING
.PARAMETER BackupType
    Show backups with the specified type. i.e. MANUAL or POLICY
.PARAMETER MinSizeMB
    Show backups with the specified minimum size
.PARAMETER MaxSizeMB
    Show backups with the specified maximum size
.PARAMETER Date
    Display backups created on the specified date. This takes precedence over CreatedAfter and CreatedBefore. You can
    specify a date only (shows 24 hours worth of backups) or a date and time, using the local date/time format.
.PARAMETER CreatedAfter
    Display backups created after the specified date. This parameter is ignored if -Date is also specified.
.PARAMETER CreatedBefore
    Display backup created before the specified date. This parameter is ignored if -Date is also specified.
.PARAMETER ExpiresAfter
    Display backups that expire after the specified date.
.PARAMETER ExpiresBefore
    Display backup that expire before the specified date.
.PARAMETER Hour
    Display backups created within the specified last number of hours. By default, backups from the last 24 hours
    are shown. This parameter is ignored when any other date related parameter is also specified.
.PARAMETER Sort
    Display backups sorted by a specified property. By default, the sort order is descending, based on backup
    creation date (CreateDate). Other accepted properties are VmName, BackupName, BackupSize, ExpiryDate,
    ClusterName and DatastoreName.
.PARAMETER Ascending
    Display backups sorted by a specified property in ascending order.
.PARAMETER All
    Bypass the default 500 record limit (and the upper maximum limit of 3000 records). When this parameter is
    specified, multiple calls are made to the SimpliVity API using an offset, until all backups are retrieved.
    This can take a long time to complete, so it is recommended to use other parameters, like -VmName or
    -DatastoreName to limit the output to those specific parameters.
.PARAMETER Limit
    By default, display 500 backups. Limit allows you to specify a value between 1 and 3000. A limit of 1 is
    useful to use with -Verbose, to quickly show how many backups would be returned with a higher limit. Limit
    is ignored if -All is specified.
.EXAMPLE
    PS C:\>Get-SvtBackup

    Show the last 24 hours of backups from the SimpliVity Federation, limited to 500 backups.
.EXAMPLE
    PS C:\>Get-SvtBackup -Date 23/04/2020
    PS C:\>Get-SvtBackup -Date '23/04/2020 10:00:00 AM'

    The first command shows all backups from the specified date (24 hour period), up to the default limit of 500
    backups. The second command shows the specific backup from the specified date and time (using local date/time
    format).
.EXAMPLE
    PS C:\>Get-SvtBackup -CreatedAfter "04/04/2020 10:00 AM" -CreatedBefore "04/04/2020 02:00 PM"

    Show backups created between the specified dates/times. (using local date/time format). Limited to 500
    backups by default.
.EXAMPLE
    PS C:\>Get-SvtBackup -ExpiresAfter "04/04/2020" -ExpiresBefore "05/04/2020" -Limit 3000

    Show backups that will expire between the specified dates/times. (using local date/time format). Limited to
    display up to the maximum of 3000 backups.
.EXAMPLE
    PS C:\>Get-SvtBackup -Hour 48 -Limit 2000 |
        Select-Object VmName, DatastoreName, SentMB, UniqueSizeMB | Format-Table -Autosize

    Show backups up to 48 hours old and display specific properties. Limited to display up to 2000 backups.
.EXAMPLE
    PS C:\>Get-SvtBackup -All -Verbose

    Shows all backups with no limit. This command may take a long time to complete because it makes multiple
    calls to the SimpliVity API until all backups are returned. It is recommended to use other parameters with
    the -All parameter to restrict the number of backups returned. (such as -DatastoreName or -VmName).
.EXAMPLE
    PS C:\>Get-SvtBackup -DatastoreName DS01 -All

    Shows all backups for the specified Datastore with no upper limit. This command will take a long time
    to complete.
.EXAMPLE
    PS C:\>Get-SvtBackup -VmName Vm1,Vm2 -BackupName 2020-03-28T16:00+10:00
    PS C:\>Get-SvtBackup -VmName Vm1,Vm2,Vm3 -Hour 2

    The first command shows backups for the specified VMs with the specified backup name.
    The second command shows the backups taken within the last 2 hours for each specified VM.
    The use of multiple, comma separated values works when connected to a Managed Virtual Appliance only.
.EXAMPLE
    PS C:\>Get-SvtBackup -VmName VM1 -BackupName '2019-05-05T00:00:00-04:00' -DestinationName SvtCluster

    If you have backup policies with more than one rule, further refine the filter by specifying the destination
    SimpliVity cluster or external store.
.EXAMPLE
    PS C:\>Get-SvtBackup -Datastore DS01,DS02 -Limit 1000

    Shows all backups on the specified SimpliVity datastores, up to the specified limit
.EXAMPLE

    PS C:\>Get-SvtBackup -ClusterName cluster1 -Limit 1 -Verbose

    Shows a quick way to determine the number of backups on a cluster without showing them
    all. The -Verbose parameter will always display the number of backups that meet the command criteria.
.EXAMPLE
    PS C:\>Get-SvtBackup -DestinationName cluster1

    Show backups located on the specified cluster or external store.

    You can specify multiple destinations, but they must all be of the same type. i.e. SimpliVity clusters
    or external stores.
.EXAMPLE
    PS C:\>Get-SvtBackup -DestinationName StoreOnce-Data02,StoreOnce-Data03 -ExpireAfter 31/12/2020

    Shows backups on the specified external datastores that will expire after the specified date (using local
    date/time format)
.EXAMPLE
    PS C:\>Get-SvtBackup -BackupState FAILED -Limit 20

    Show a list of failed backups, limited to 20 backups.
.EXAMPLE
    PS C:\>Get-SvtBackup -Datastore DS01 -BackupType MANUAL

    Show a list of backups that were manually taken for VMs residing on the specified datastore.
.EXAMPLE
    PS C:\>Get-SvtVm -ClusterName cluster1 | Foreach-Object { Get-SvtBackup -VmName $_.VmName -Limit 1 }
    PS C:\>Get-SvtVm -Name Vm1,Vm2,Vm3 | Foreach-Object { Get-SvtBackup -VmName $_.VmName -Limit 1 }

    Display the latest backup for each specified VM
.EXAMPLE
    PS C:\>Get-SvtBackup -Sort BackupSize
    PS C:\>Get-SvtBackup -Sort ExpiryDate -Ascending

    Display backups sorted by a specified property. By default, the sort order is descending but this can be
    overridden using the -Ascending switch. Accepted properties are VmName, BackupName, BackupSize, CreateDate,
    ExpiryDate, ClusterName and DatastoreName. The default sort property is CreateDate.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Backup
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    Known issues with the REST API Get operations for Backup objects:
    1. OMNI-53190 REST API Limit recommendation for REST GET backup object calls.
    2. OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints.
    3. Filtering on a cluster destination also displays external store backups. This issue applies when connected to
    SimpliVity Virtual Appliances only. It works as expected when connected to a Managed Virtual Appliance.
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtBackup.md
#>
function Get-SvtBackup {
    [CmdletBinding(DefaultParameterSetName = 'ByVmName')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVmName')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [System.String[]]$Clustername,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String[]]$DatastoreName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByBackupId')]
        [Alias('Id')]
        [System.String[]]$BackupId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [Alias('Name')]
        [System.String[]]$BackupName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String[]]$DestinationName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [ValidateSet('PROTECTED', 'SAVING', 'QUEUED', 'FAILED')]
        [System.String[]]$BackupState,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [ValidateSet('POLICY', 'MANUAL')]
        [System.String[]]$BackupType,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.Int32]$MinSizeMB,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.Int32]$MaxSizeMB,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [Alias('CreationDate')]
        [System.String]$Date,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String]$CreatedAfter,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String]$CreatedBefore,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String]$ExpiresAfter,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String]$ExpiresBefore,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [ValidateRange(1, 175400)]   # up to 20 years
        [System.String]$Hour,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [ValidateSet('VmName', 'BackupName', 'BackupSize', 'CreateDate', 'ExpiryDate', 'ClusterName', 'DatastoreName')]
        [System.String]$Sort = 'CreateDate',

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [switch]$Ascending,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [switch]$All,

        # HPE recommends 500 default, 3000 maximum (OMNI-53190)
        [Parameter(Mandatory = $false, ParameterSetName = 'ByVmName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [ValidateRange(1, 3000)]
        [System.Int32]$Limit = 500
    )

    #$VerbosePreference = 'Continue'
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }
    $LocalFormat = Get-SvtLocalDateFormat
    $LocalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    $Offset = 0

    # Case sensitivity is problematic with /backups API. Some properties do not support case insensitive
    # filter, so assuming case sensitive for all.
    $Uri = "$($global:SvtConnection.VA)/api/backups?case=sensitive"

    if ($PSBoundParameters.ContainsKey('All')) {
        $Limit = 3000
        $Uri += "&limit=$Limit"
        if ($PSBoundParameters.Count -le 1) {
            $Message = 'This command may take a long time to complete. Consider using other parameters ' +
            'with -All to limit the output'
            Write-Warning $Message
        }
    }
    else {
        # Using default (500) or some user specified limit (1-3000)
        $Uri += "&limit=$Limit"
    }

    if ($PSBoundParameters.ContainsKey('VmName')) {
        Write-Verbose 'VM names are case sensitive'
        $Uri += "&virtual_machine_name=$($VmName -join ',')"
    }
    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        Write-Verbose 'Cluster names are case sensitive'
        $Uri += "&omnistack_cluster_name=$($ClusterName -join ',')"
    }
    if ($PSBoundParameters.ContainsKey('DatastoreName')) {
        Write-Verbose 'Datastore names are case sensitive'
        $Uri += "&datastore_name=$($DatastoreName -join ',')"
    }
    if ($PSBoundParameters.ContainsKey('DestinationName')) {
        try {
            $Destination = Get-SvtBackupDestination -Name $DestinationName -ErrorAction Stop
            if (($Destination.Type | Select-Object -First 1) -eq 'Cluster') {
                $Uri += "&omnistack_cluster_id=$($Destination.Id -join ',')"
            }
            else {
                $Uri += "&external_store_name=$($Destination.Name -join ',')"
            }
        }
        catch {
            throw $_.Exception.Message
        }
    }
    if ($PSBoundParameters.ContainsKey('BackupName')) {
        Write-Verbose 'Backup names are case sensitive. Incomplete backup names are matched'
        # add an asterisk to each backup name to support incomplete name match. Also replace plus symbol
        $Uri += "&name=$(($BackupName -join '*,') + '*' -replace '\+', '%2B' -replace ':', '%3A')"
    }
    if ($PSBoundParameters.ContainsKey('BackupId')) {
        $Uri += "&id=$($BackupId -join ',')"
    }
    if ($PSBoundParameters.ContainsKey('BackupState')) {
        $Uri += "&state=$($BackupState -join ',')"
    }
    if ($PSBoundParameters.ContainsKey('BackupType')) {
        $Uri += "&type=$(($BackupType -join ',').ToUpper())"
    }
    if ($PSBoundParameters.ContainsKey('MinSizeMB')) {
        $Uri += "&size_min=$($MinSizeMB * 1mb)"
    }
    if ($PSBoundParameters.ContainsKey('MaxSizeMB')) {
        $Uri += "&size_max=$($MaxSizeMB * 1mb)"
    }
    if ($PSBoundParameters.ContainsKey('Date')) {
        # The Date parameter takes precedence over the CreatedAfter and CreatedBefore parameters
        try {
            $DateRange = Get-SvtDateRange -Date $Date
        }
        catch {
            throw $_.Exception.Message
        }
        $Uri += "&created_before=$($DateRange.Before)&created_after=$($DateRange.After)"
    }
    else {
        if ($PSBoundParameters.ContainsKey('CreatedAfter')) {
            $StartDate = Get-Date -Date "$CreatedAfter"
            $After = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
            $Uri += "&created_after=$After"
        }
        if ($PSBoundParameters.ContainsKey('CreatedBefore')) {
            $EndDate = Get-Date -Date "$CreatedBefore"
            $Before = "$(Get-Date $($EndDate.ToUniversalTime()) -format s)Z"
            $Uri += "&created_before=$Before"
        }
    }
    if ($PSBoundParameters.ContainsKey('ExpiresAfter')) {
        $StartDate = Get-Date -Date "$ExpiresAfter"
        $After = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
        $Uri += "&expires_after=$After"
    }
    if ($PSBoundParameters.ContainsKey('ExpiresBefore')) {
        $EndDate = Get-Date -Date "$ExpiresBefore"
        $Before = "$(Get-Date $($EndDate.ToUniversalTime()) -format s)Z"
        $Uri += "&expires_before=$Before"
    }

    $SortProperty = Get-SvtSortString -Sort $Sort
    $Uri += "&sort=$SortProperty"
    if ($PSBoundParameters.ContainsKey('Ascending')) {
        # by default, backups are displayed in descending order. This can be overridden using the -Ascending switch
        $Uri += "&order=ascending"
    }

    if ($PSBoundParameters.ContainsKey('Hour')) {
        # -Hour specified but ignore if any other date related parameter is specified
        $ParamList = @('Date', 'CreatedAfter', 'CreatedBefore', 'ExpiresAfter', 'ExpiresBefore')
        $ParamFound = @()
        foreach ($Param in $ParamList) {
            if ($Param -in $PSBoundParameters.Keys) {
                $ParamFound += $Param
            }
        }
        if ($ParamFound) {
            $Message = "$($ParamFound -join ',') specified, ignoring -Hour parameter"
            Write-Verbose $Message
        }
        else {
            $StartDate = (Get-Date).AddHours(-$Hour)
            $CreatedAfter = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
            $Uri += "&created_after=$CreatedAfter"

            $Message = "Displaying backups from the last $Hour hours, " +
            "(created after $(Get-date $StartDate -Format $LocalFormat)), limited to $limit backups"
            Write-Verbose $Message
        }
    }
    else {
        # -Hour not specified. Show the last 24 hours by default, but only when no other parameters are specified.
        # This approach is safer than counting passed in parameters - the user may specify -Verbose or other
        # common parameters, which would affect the behavior. -Limit, -Sort and -Ascending are allowed.
        $ParamList = @('VmName', 'ClusterName', 'DatastoreName', 'BackupId', 'DestinationName', 'BackupName',
            'BackupState', 'BackupType', 'MinSizeMB', 'MaxSizeMB', 'All', 'Date', 'CreatedAfter',
            'CreatedBefore', 'ExpiresAfter', 'ExpiresBefore')
        $ParamFound = $false
        foreach ($Param in $ParamList) {
            if ($Param -in $PSBoundParameters.Keys) {
                $ParamFound = $true
            }
        }
        if (-not $ParamFound) {
            $StartDate = (Get-Date).AddHours(-24)
            $CreatedAfter = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
            $Uri += "&created_after=$CreatedAfter"
            $Message = 'Displaying backups from the last 24 hours,' +
            "(created after $(Get-date $StartDate -Format $LocalFormat)), limited to $limit backups"
            Write-Verbose $Message
        }
    }

    do {
        $ThisUri = $Uri + "&offset=$Offset"
        try {
            $Response = Invoke-SvtRestMethod -Uri $ThisUri -Header $Header -Method Get -ErrorAction Stop
            $BackupCount = $Response.Count
        }
        catch {
            throw $_.Exception.Message
        }

        if ($PSBoundParameters.ContainsKey('All')) {
            Write-Verbose "There are $BackupCount matching backups, offset $Offset used"
            $Offset += $Limit
        }
        else {
            # -All not specified, so drop out after 1 loop
            $Offset = $BackupCount

            if ($BackupCount -gt $Limit) {
                $Message = "There are $BackupCount matching backups, but limited to displaying $Limit only. " +
                'Either increase -Limit or use more restrictive parameters'
                Write-Verbose $Message
            }
            else {
                Write-Verbose "There are $BackupCount matching backups"
            }
        }

        if (-not $Response.Backups.Name -and $PSBoundParameters.Count -gt 0) {
            throw "No matching backups found using the specified parameter(s)"
        }

        $Response.backups | ForEach-Object {
            if ($_.omnistack_cluster_name) {
                $Destination = $_.omnistack_cluster_name
            }
            else {
                $Destination = $_.external_store_name
            }

            if ($PSEdition -eq 'Core' -and $_.name -as [datetime]) {
                # When converting from json, Invoke-RestMethod with PowerShell Core 'conveniently' converts 
                # UTC dates into local date objects. This is not what we want for the backup name, the date object 
                # must be converted back to a UTC string, as per output from the REST API. This is not quite 
                # ISO 8601 (sortable time) format, as displayed with Get-Date -format s, nor RF1123 as displayed 
                # by Get-Date -Format r.
                # NOTE: a future version of PowerShell Core will supposedly allow suppression of this automatic 
                # conversion of UTC dates.
                $LocalBackupName = Get-Date -Date $_.name -Format 'yyyy-MM-ddTHH:mm:sszzz'
            }
            else {
                # Windows PowerShell doesn't mess with UTC strings
                $LocalBackupName = $_.name
            }

            # Converting numeric strings to numbers so that subsequent sorting is possible. Must use locale to
            # format correctly
            [PSCustomObject]@{
                PSTypeName        = 'HPE.SimpliVity.Backup'
                VmName            = $_.virtual_machine_name
                CreateDate        = ConvertFrom-SvtUtc -Date $_.created_at
                ConsistencyType   = $_.consistency_type
                BackupType        = $_.type
                DatastoreName     = $_.datastore_name
                VmId              = $_.virtual_machine_id
                AppConsistent     = $_.application_consistent
                ParentId          = $_.compute_cluster_parent_hypervisor_object_id
                ExternalStoreName = $_.external_store_name
                BackupId          = $_.id
                BackupState       = $_.state
                ClusterId         = $_.omnistack_cluster_id
                VmType            = $_.virtual_machine_type
                SentCompleteDate  = $_.sent_completion_time
                UniqueSizeMB      = [single]::Parse('{0:n0}' -f ($_.unique_size_bytes / 1mb), $LocalCulture)
                ClusterGroupIDs   = $_.cluster_group_ids
                UniqueSizeDate    = ConvertFrom-SvtUtc -Date $_.unique_size_timestamp
                ExpiryDate        = ConvertFrom-SvtUtc -Date $_.expiration_time
                ClusterName       = $_.omnistack_cluster_name
                SentMB            = [single]::Parse('{0:n0}' -f ($_.sent / 1mb), $LocalCulture)
                SizeGB            = [single]::Parse('{0:n2}' -f ($_.size / 1gb), $LocalCulture)
                SizeMB            = [single]::Parse('{0:n0}' -f ($_.size / 1mb), $LocalCulture)
                VmState           = $_.virtual_machine_state
                BackupName        = $LocalBackupName
                DatastoreId       = $_.datastore_id
                DataCenterName    = $_.compute_cluster_parent_name
                HypervisorType    = $_.hypervisor_type
                SentDuration      = [System.Int32]$_.sent_duration
                DestinationName   = $Destination
            }
        } #end foreach backup object
    } until ($Offset -ge $BackupCount)
}

<#
.SYNOPSIS
    Create one or more new HPE SimpliVity backups
.DESCRIPTION
    Creates a backup of one or more virtual machines hosted on HPE SimpliVity. Either specify the VM names
    via the VmName parameter or use Get-SvtVm output to pass in the HPE SimpliVity VM objects to backup.
    Backups are directed to the specified destination cluster or external store, or to the local cluster
    for each VM if no destination name is specified.
.PARAMETER VmName
    The virtual machine(s) to backup. Optionally use the output from Get-SvtVm to provide the required VM names.
.PARAMETER DestinationName
    The destination cluster name or external store name. If nothing is specified, the virtual machine(s)
    is/are backed up locally. If there is a cluster with the same name as an external store, the cluster wins.
.PARAMETER BackupName
    Give the backup(s) a unique name, otherwise a default name with a date stamp is used.
.PARAMETER RetentionDay
    Specifies the retention in days.
.PARAMETER RetentionHour
    Specifies the retention in hours. This parameter takes precedence if RetentionDay is also specified.
.PARAMETER ConsistencyType
    Available options are:
    1. NONE - This is the default and creates a crash consistent backup
    2. DEFAULT - Create application consistent backups using VMware Snapshot
    3. VSS - Create application consistent backups using Microsoft VSS in the guest operating system. Refer
       to the admin guide for requirements and supported applications
.EXAMPLE
    PS C:\> New-SvtBackup -VmName MyVm -DestinationName ClusterDR

    Backup the specified VM to the specified SimpliVity cluster, using the default backup name and retention
.EXAMPLE
    PS C:\> New-SvtBackup MyVm StoreOnce-Data01 -RetentionDay 365 -ConsistencyType DEFAULT

    Backup the specified VM to the specified external datastore, using the default backup name and retain the
    backup for 1 year. A consistency type of DEFAULT creates a VMware snapshot to quiesce the disk prior to
    taking the backup
.EXAMPLE
    PS C:\> New-SvtBackup -BackupName "BeforeSQLupgrade" -VmName SQL01 -DestinationName SvtCluster -RetentionHour 2

    Backup the specified SQL server with a backup name and a short (2 hour) retention
.EXAMPLE
    PS C:\> Get-SvtVm | ? VmName -match '^DB' | New-SvtBackup -BackupName 'Manual backup prior to SQL upgrade'

    Locally backup up all VMs with names starting with 'DB' using the specified backup name and with default
    retention of 1 day.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtBackup.md
#>
function New-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$VmName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$DestinationName,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$BackupName = "Created by $(($SvtConnection.Credential.Username -split '@')[0]) at " +
        "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')",

        [Parameter(Mandatory = $false, Position = 3)]
        [System.Int32]$RetentionDay = 1,

        [Parameter(Mandatory = $false, Position = 3)]
        [System.Int32]$RetentionHour,

        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('DEFAULT', 'VSS', 'NONE')]
        [System.String]$ConsistencyType = 'NONE'
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        if ($PSBoundParameters.ContainsKey('DestinationName')) {
            try {
                $Destination = Get-SvtBackupDestination -Name $DestinationName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }

        if ($ConsistencyType -eq 'NONE') {
            $ApplicationConsistent = $false
        }
        else {
            $ApplicationConsistent = $true
        }

        if ($PSBoundParameters.ContainsKey('RetentionHour')) {
            # Must be specified in minutes
            $Retention = $RetentionHour * 60
        }
        else {
            # Must be specified in minutes. Retention will be 1 day by default.
            $Retention = $RetentionDay * 1440
        }
    }

    process {
        foreach ($VM in $VmName) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in
                # the begin block might be a problem on systems with a large number of VMs.
                $VmObj = Get-SvtVm -VmName $VM -ErrorAction Stop
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmObj.VmId + '/backup'
            }
            catch {
                throw $_.Exception.Message
            }

            $Body = @{
                'backup_name'      = $BackupName -replace "'", ""
                'app_consistent'   = $ApplicationConsistent
                'consistency_type' = $ConsistencyType
                'retention'        = $Retention
            }

            if ($Destination.Type -eq 'Cluster') {
                $Body += @{ 'destination_id' = $Destination.Id }
            }
            elseif ($Destination.Type -eq 'ExternalStore') {
                $Body += @{ 'external_store_name' = $Destination.Id }
            }
            else {
                # No destination cluster/external store specified, so backup to the local cluster
                $Body += @{ 'destination_id' = $VmObj.ClusterId }
            }

            $Body = $Body | ConvertTo-Json
            Write-Verbose $Body

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message) Backup failed for VM $VM"
            }
        } #end foreach
    } #end process

    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Restore one or more HPE SimpliVity virtual machines
.DESCRIPTION
    Restore one or more virtual machines from backups hosted on HPE SimpliVity storage. Use output from the
    Get-SvtBackup command to pass in the backup(s) you want to restore. By default, a new VM is created for each
    backup passed in. The new virtual machines are named after the original VM name with a timestamp suffix to make
    them unique. Alternatively, you can specify the -RestoreToOriginal switch to restore to the original virtual
    machines. This action will overwrite the existing virtual machines, recovering to the state of the backup used.

    However, if -NewVmName is specified, you can only pass in one backup object. The first backup passed in will
    be restored with the specified VmName, but subsequent restores will not be attempted and an error will be
    displayed. In addition, if you specify a new VM name that this is already in use by an existing VM, then the
    restore task will fail with a duplicate name error.

    By default the datastore used by the original VMs are used for each restore. If -DatastoreName is specified,
    the restored VMs will be located on the specified datastore.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to
    identify the backups you want to target and then pass the output to this command.
.PARAMETER RestoreToOriginal
    Specifies that the VM is restored to original location, overwriting the existing virtual machine, if it exists
.PARAMETER BackupId
    The UID of the backup(s) to restore from
.PARAMETER NewVmName
    Specify a new name for the virtual machine when restoring one VM only
.PARAMETER DatastoreName
    The destination datastore name. If not specified, the original datastore location from each backup is used
.EXAMPLE
    PS C:\> Get-SvtBackup -BackupName 2019-05-09T22:00:00+10:00 | Restore-SvtVm -RestoreToOriginal

    Restores the virtual machine(s) in the specified backup to the original virtual machine(s)
.EXAMPLE
    PS C:\> Get-SvtBackup -VmName MyVm -Limit 1 | Restore-SvtVm

    Restores the most recent backup of specified virtual machine, giving it a new name comprising of the name of
    the original VM with a date stamp appended to ensure uniqueness
.EXAMPLE
    PS C:\> Get-SvtBackup -VmName MyVm -Limit 1 | Restore-SvtVm -NewVmName MyOtherVM

    Restores the most recent backup of specified virtual machine, giving it the specified name. NOTE: this command
    will only work for the first backup passed in. Subsequent restores are not attempted and an error is displayed.
.EXAMPLE
    PS> $LatestBackup = Get-SvtVm -VmName VM1,VM2,VM3 | Foreach-Object { Get-SvtBackup -VmName $_.VmName -Limit 1 }
    PS> $LatestBackup | Restore-SvtVm -DatastoreName DS2

    Restores the most recent backup of each specified virtual machine, creating a new copy of each on the specified
    datastore. The virtual machines will have new names comprising of the name of the original VM with a date
    stamp appended to ensure uniqueness
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Restore-SvtVm.md
#>
function Restore-SvtVm {
    # calling this function 'restore VM' rather than 'restore backup' as per the API, because it makes more sense
    [CmdletBinding(DefaultParameterSetName = 'RestoreToOriginal')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'RestoreToOriginal')]
        [switch]$RestoreToOriginal,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'NewVm')]
        [Alias('VmName')]
        [System.String]$NewVmName,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NewVm')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 4, ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $DateSuffix = Get-Date -Format 'yyMMddhhmmss'
        $FirstError = $null
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        if (-not $PSBoundParameters.ContainsKey('RestoreToOriginal')) {
            try {
                $AllDatastore = Get-SvtDatastore -ErrorAction Stop
                $Count = 1
            }
            catch {
                throw $_.Exception.Message
            }
        }
    }
    process {
        foreach ($BkpId in $BackupId) {
            if ($PSBoundParameters.ContainsKey('RestoreToOriginal')) {
                # Restoring a VM from an external store backup with 'RestoreToOriginal' is currently
                # not supported. So check if the backup is located on an external store.
                try {
                    $ThisBackup = Get-SvtBackup -BackupId $BkpId -ErrorAction Stop
                    if ($ThisBackup.ExternalStoreName) {
                        $Message = "Restoring VM $($ThisBackup.VmName) from a backup located on an external " +
                        "store with 'RestoreToOriginal' set is not supported"
                        throw $Message
                    }
                }
                catch {
                    # Don't exit, continue with other restores in the pipeline
                    Write-Error $_.Exception.Message
                    if (-not $FirstError) {
                        $FirstError = $_.Exception.Message
                    }
                    continue
                }
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/restore?restore_original=true'
            }
            else {
                # Not restoring to original and user specified a new VM Name
                if ($NewVmName) {
                    if ($Count -gt 1) {
                        $global:SvtTask = $AllTask
                        throw "With multiple restores, you cannot specify a new VM name, only the first backup is restored"
                    }
                    else {
                        # Works for the first VM in the pipeline only
                        Write-Verbose "Restoring VM with new name $NewVmName"
                        $RestoreVmName = $NewVmName
                    }
                }
                # Not restoring to original and no new name specified, so use existing VM names with a timestamp suffix
                else {
                    try {
                        $VmName = Get-SvtBackup -BackupId $BkpId -ErrorAction Stop |
                        Select-Object -ExpandProperty VmName
                    }
                    catch {
                        # Don't exit, continue with other restores in the pipeline
                        Write-Error $_.Exception.Message
                        if (-not $FirstError) {
                            $FirstError = $_.Exception.Message
                        }
                        continue
                    }

                    if ($VmName.Length -gt 59) {
                        $RestoreVmName = "$($VmName.Substring(0, 59))-restore-$DateSuffix"
                    }
                    else {
                        $RestoreVmName = "$VmName-restore-$DateSuffix"
                    }
                }
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/restore?restore_original=false'

                try {
                    $DatastoreId = $AllDatastore | Where-Object DatastoreName -eq $DatastoreName |
                    Select-Object -ExpandProperty DatastoreId
                }
                catch {
                    # Don't exit, continue with other restores in the pipeline
                    Write-Error $_.Exception.Message
                    if (-not $FirstError) {
                        $FirstError = $_.Exception.Message
                    }
                    continue
                }

                $Body = @{
                    'datastore_id'         = $DatastoreId
                    'virtual_machine_name' = $RestoreVmName
                } | ConvertTo-Json
                Write-Verbose $Body
            }

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
                $Count += 1
            }
            catch {
                Write-Error "$($_.Exception.Message), restore failed for VM $RestoreVmName"
                if (-not $FirstError) {
                    $FirstError = $_.Exception.Message
                }
            }
        } #end for
    } # end process
    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used

        if ($FirstError) {
            throw $FirstError
        }
    }
}

<#
.SYNOPSIS
    Delete one or more HPE SimpliVity backups
.DESCRIPTION
    Deletes one or more backups hosted on HPE SimpliVity. Use Get-SvtBackup output to pass in the backup(s)
    to delete or specify the Backup ID, if known.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to
    identify the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    The UID of the backup(s) to delete
.EXAMPLE
    PS C:\> Get-SvtBackup -BackupName 2019-05-09T22:00:01-04:00 | Remove-SvtBackup

    Deletes the backups with the specified backup name.
.EXAMPLE
    PS C:\> Get-SvtBackup -VmName MyVm -Hour 3 | Remove-SvtBackup

    Delete any backup that is at least 3 hours old for the specified virtual machine
.EXAMPLE
    PS C:\> Get-SvtBackup | ? VmName -match "test" | Remove-SvtBackup

    Delete all backups for all virtual machines that have "test" in their name
.EXAMPLE
    PS C:\> Get-SvtBackup -CreatedBefore 01/01/2020 -Limit 3000 | Remove-SvtBackup

    This command will remove backups older than the specified date.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This cmdlet uses the /api/backups/delete REST API POST call which creates a task to delete the specified
    backup. This call accepts multiple backup IDs, and efficiently removes multiple backups with a single task.
    This also works for backups in remote clusters.

    There is another REST API DELETE call (/api/backups/<bkpId>) which only works locally (i.e. when
    connected to a SimpliVity Virtual Appliance where the backup resides), but this fails when trying to delete
    remote backups.
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtBackup.md
#>
function Remove-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $BackupList = @()
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $Uri = $global:SvtConnection.VA + '/api/backups/delete'
    }

    process {
        foreach ($BkpId in $BackupId) {
            $BackupList += $BkpId
        }
    }

    end {
        $Body = @{ 'backup_id' = $BackupList } | ConvertTo-Json
        Write-Verbose $Body
        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SvtTask = $Task
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Stops (cancels) a currently executing HPE SimpliVity backup
.DESCRIPTION
    Stops (cancels) a currently executing HPE SimpliVity backup

    SimpliVity backups finish almost immediately, so cancelling a backup is unlikely. Once the backup is 
    completed, the backup state is 'Protected' and the backup task cannot be stopped. Backups to external 
    storage take longer (backup state is shown as 'Saving') and are more likely to be running long enough 
    to cancel.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Specify the Backup ID(s) for the backup(s) to cancel
.EXAMPLE
    PS C:\> Get-SvtBackup | Where-Object BackupState -eq 'Saving' | Stop-SvtBackup

    Cancels the backup or backups with the specified backup state.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtBackup.md
#>
function Stop-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $FirstError = $null
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/cancel'

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Error "$($_.Exception.Message), failed to stop backup with id $BkpId"
                if (-not $FirstError) {
                    $FirstError = $_.Exception.Message
                }
            }
        }
    }

    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used

        if ($FirstError) {
            throw $FirstError
        }
    }
}

<#
.SYNOPSIS
    Copy HPE SimpliVity backups to another cluster or to an external store
.DESCRIPTION
    Copy HPE SimpliVity backups between SimpliVity clusters and backups to and from external stores.

    Note that currently backups on external stores can only be copied to the cluster they were backed
    up from. In addition, a backup on an external store cannot be copied to another external store.

    If you try to copy a backup to a destination where it already exists, the task will fail with a "Duplicate
    name exists" message.

    BackupId is the only unique identifier for backup objects (i.e. backups for each VM have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to
    identify the backups you want to target and then pass the output to this command.
.PARAMETER DestinationName
    Specify the destination SimpliVity Cluster name or external store name. If a cluster exists with the
    same name as an external store, the cluster wins.
.PARAMETER BackupId
    Specify the Backup ID(s) to copy. Use the output from an appropriate Get-SvtBackup command to provide
    one or more Backup ID's to copy.
.EXAMPLE
    PS C:\> Get-SvtBackup -VmName Win2019-01 | Copy-SvtBackup -DestinationName Cluster02

    Copy the last 24 hours of backups for the specified VM to the specified SimpliVity cluster
.EXAMPLE
    PS C:\> Get-SvtBackup -Hour 2 | Copy-SvtBackup Cluster02

    Copy the last two hours of all backups to the specified cluster
.EXAMPLE
    PS C:\> Get-SvtBackup -Name 'BeforeSQLupgrade' | Copy-SvtBackup -DestinationName StoreOnce-Data02

    Copy backups with the specified name to the specified external store.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Copy-SvtBackup.md
#>
function Copy-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DestinationName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        try {
            $Destination = Get-SvtBackupDestination -Name $DestinationName -ErrorAction Stop

            if ($Destination.Type -eq 'Cluster') {
                $Body = @{ 'destination_id' = $Destination.Id } | ConvertTo-Json
                Write-Verbose $Body
            }
            else {
                $Body = @{ 'external_store_name' = $Destination.Id } | ConvertTo-Json
                Write-Verbose $Body
            }
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            try {
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/copy'
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), copy failed for backup with id $BkpId"
            }
        }
    }
    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Locks HPE SimpliVity backups to prevent them from expiring
.DESCRIPTION
    Locks HPE SimpliVity backups to prevent them from expiring

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Lock the backup(s) with the specified backup ID(s)
.EXAMPLE
    PS C:\> Get-SvtBackup -BackupName 2019-05-09T22:00:01-04:00 | Lock-SvtBackup
    PS C:\> Get-SvtTask

    Locks the backup(s) with the specified name. Use Get-SvtTask to track the progress of the task(s).
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Lock-SvtBackup.md
#>
function Lock-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $FirstError = $null
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/lock'

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Error "$($_.Exception.Message), failed to lock backup with id $BkpId"
                if (-not $FirstError) {
                    $FirstError = $_.Exception.Message
                }
            }

        }
    }
    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used

        if ($FirstError) {
            throw $FirstError
        }
    }
}

<#
.SYNOPSIS
    Rename existing HPE SimpliVity backup(s)
.DESCRIPTION
    Rename existing HPE SimpliVity backup(s).

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupName
    The new backup name. Must be a new unique name. The command fails if there are existing backups with
    this name.
.PARAMETER BackupId
    The backup Ids of the backups to be renamed
.EXAMPLE
    PS C:\> Get-SvtBackup -BackupName "Pre-SQL update"
    PS C:\> Get-SvtBackup -BackupName 2019-05-11T09:30:00-04:00 | Rename-SvtBackup "Pre-SQL update"

    The first command confirms the backup name is not in use. The second command renames the specified backup(s).
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Rename-SvtBackup.md
#>
function Rename-SvtBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [Alias('NewName')]
        [System.String]$BackupName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $FirstError = $null
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/rename'

            $Body = @{ 'backup_name' = $BackupName } | ConvertTo-Json
            Write-Verbose $Body

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Error "$($_.Exception.Message), rename failed for backup $BkpId"
                if (-not $FirstError) {
                    $FirstError = $_.Exception.Message
                }
            }
        }
    }
    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used

        if ($FirstError) {
            throw $FirstError
        }
    }
}

<#
.SYNOPSIS
    Set the retention of existing HPE SimpliVity backups
.DESCRIPTION
    Change the retention on existing SimpliVity backup.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same
    name). This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup
    to identify the backups you want to target and then pass the output to this command.

    Note: There is currently a known issue with the REST API that prevents you from setting retention times
    that will cause backups to immediately expire. if you try to decrease the retention for a backup policy
    where backups will be immediately expired, you'll receive an error in the task.
.PARAMETER RetentionDay
    The new retention you would like to set, in days.
.PARAMETER RetentionHour
    The new retention you would like to set, in hours.
.PARAMETER BackupId
    The UID of the backup you'd like to set the retention for
.EXAMPLE
    PS C:\> Get-Backup -BackupName 2019-05-09T22:00:01-04:00 | Set-SvtBackupRetention -RetentionDay 21

    Gets the backups with the specified name and then sets the retention to 21 days.
.EXAMPLE
    PS C:\> Get-Backup -VmName Win2019-04 -Limit 1 | Set-SvtBackupRetention -RetentionHour 12

    Get the latest backup of the specified virtual machine and then sets the retention to 12 hours.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    OMNI-53536: Setting the retention time to a time that causes backups to be deleted fails
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtBackupRetention.md
#>
function Set-SvtBackupRetention {
    [CmdletBinding(DefaultParameterSetName = 'ByDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByDay')]
        [System.Int32]$RetentionDay,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHour')]
        [System.Int32]$RetentionHour,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId

        # Force is supported by the API - it tells SimpliVity to set the retention even if backups
        # will be expired. This currently doesn't work, though. For now, this parameter is disabled so
        # if you try to decrease the retention for a backup policy where backups will be immediately
        # expired, you'll receive an error in the task.
        # [Parameter(Mandatory=$true, Position=2)]
        # [Switch]$Force
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        $Uri = $global:SvtConnection.VA + '/api/backups/set_retention'
        $BackupIdList = @()

        $ForceRetention = $false
        if ($PSBoundParameters.ContainsKey('Force')) {
            Write-Warning 'Possible deletion of some backups, depending on age and retention set'
            $ForceRetention = $true
        }
        if ($PSBoundParameters.ContainsKey('RetentionHour')) {
            $Retention = $RetentionHour * 60 # Must be specified in minutes
        }
        else {
            $Retention = $RetentionDay * 1440 # Must be specified in minutes
        }
    }

    process {
        # This API call accepts a list of backup Ids. However, we are creating a task per backup ID here.
        # Using a task list with a single task may be more efficient, but its inconsistent with the other cmdlets.
        foreach ($BkpId in $BackupId) {
            $BackupIdList += $BkpId
        }
    }
    end {
        $Body = @{
            'backup_id' = @($BackupIdList) # Expects an array
            'retention' = $Retention
            'force'     = $ForceRetention
        } | ConvertTo-Json
        Write-Verbose $Body

        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop

            # If the attempted retention date is in the past, the list of backup objects is returned.
            if ($Task.Backups) {
                throw "You cannot set a retention date that would immediately expire the target backup(s)"
            }
            else {
                $Task
                $global:SvtTask = $Task
                $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
            }
        }
        catch {
            throw $_.Exception.Message
        }
    } #end
}

<#
.SYNOPSIS
    Calculate the unique size of HPE SimpliVity backups
.DESCRIPTION
    Calculate the unique size of HPE SimpliVity backups

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same
    name). This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup
    to identify the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Use Get-SvtBackup to output the required VMs as input for this command
.EXAMPLE
    PS C:\> Get-SvtBackup -VmName VM01 | Update-SvtBackupUniqueSize

    Starts a task to calculate the unique size of the specified backup(s)
.EXAMPLE
    PS:\> Get-SvtBackup -Date 26/04/2020 | Update-SvtBackupUniqueSize

    Starts a task per backup object to calculate the unique size of backups with the specified creation date.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command only updates the backups in the local cluster. Login to a SimpliVity Virtual Appliance in a remote
    cluster to update the backups there. The UniqueSizeDate property is updated on the backup object(s) when you run
    this command
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Update-SvtBackupUniqueSize.md
#>
function Update-SvtBackupUniqueSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/calculate_unique_size'

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            [array]$AllTask += $Task
            $Task
        }
    }

    end {
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Display the virtual disk, partition and file information from a SimpliVity backup
.DESCRIPTION
    Displays the backed up files inside a SimpliVity backup. Different output is produced, depending on the
    parameters provided. BackupId is a mandatory parameter and can be passed in from Get-SvtBackup.

    If no optional parameters are provided, or if VirtualDisk is not specified, the virtual disks contained
    in the backup are shown. If a virtual disk name is provided, the partitions within the specified virtual
    disk are shown. If the virtual disk and partition are provided, the files in the root path for the partition
    are shown. If all three optional parameters are provided, the specified backed up files are shown.

    Notes:
    1. This command only works with backups from Microsoft Windows VMs. with Linux VMs, only backed up 
       virtual disks and partitions can be displayed (files cannot be displayed).
    2. This command only works with native SimpliVity backups. (Backups on StoreOnce appliances do not work)
    3. Virtual disk names and folder paths are case sensitive
.PARAMETER BackupId
    The Backup Id for the desired backup. Use Get-SvtBackup to output the required backup as input for
    this command
.PARAMETER VirtualDisk
    The virtual disk name contained within the backup, including file suffix (".vmdk")
.PARAMETER PartitionNumber
    The partition number within the specified virtual disk
.PARAMETER FilePath
    The folder path for the backed up files
.EXAMPLE
    PS C:\> $Backup = Get-SvtBackup -VmName Win2019-01 -Limit 1
    PS C:\> $Backup | Get-SvtFile

    The first command identifies the most recent backup of the specified VM.
    The second command displays the virtual disks contained within the backup
.EXAMPLE
    PS C:\> $Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SvtFile -VirtualDisk Win2019-01.vmdk

    The first command identifies the most recent backup of the specified VM taken on a specific date.
    The second command displays the partitions within the specified virtual disk. Virtual disk names are
    case sensitive
.EXAMPLE
    PS C:\> Get-SvtFile -BackupId 5f5f7f06...0b509609c8fb -VirtualDisk Win2019-01.vmdk -PartitionNumber 4

    Shows the contents of the root folder on the specified partition inside the specified backup
.EXAMPLE
    PS C:\> $Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SvtFile Win2019-01.vmdk 4

    Shows the backed up files at the root of the specified partition, using positional parameters
.EXAMPLE
    PS C:\> $Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SvtFile Win2019-01.vmdk 4 /Users/Administrator/Documents

    Shows the specified backed up files within the specified partition, using positional parameters. File
    names are case sensitive.
.EXAMPLE
    PS C:\> $Backup = '5f5f7f06-a485-42eb-b4c0-0b509609c8fb' # This is a valid Backup ID
    PS C:\> $Backup | Get-SvtFile -VirtualDisk Win2019-01_1.vmdk -PartitionNumber 2 -FilePath '/Log Files'

    The first command identifies the desired backup. The second command displays the specified backed up
    files using named parameters. Quotes are used because the file path contains a space. File names are
    case sensitive.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.VirtualDisk
    HPE.SimpliVity.Partition
    HPE.SimpliVity.File
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtFile.md
#>
function Get-SvtFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$BackupId,

        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Disk')]
        [System.String]$VirtualDisk,


        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$PartitionNumber,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$FilePath
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            # User specifies the virtual disk, partition and the file path. In this case, show the specified
            # files within the backup
            if ('VirtualDisk' -in $PSBoundParameters.Keys -and 'PartitionNumber' -in $PSBoundParameters.Keys) {
                if ('FilePath' -in $PSBoundParameters.Keys) {
                    $Folder = $FilePath #-replace '/', '%2F'
                }
                else {
                    #File path was not specified, so show the root path ('/')
                    $Folder = '/' #'%2F'
                }
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/virtual_disk_partition_files' +
                '?virtual_disk=' + $VirtualDisk + '&partition_number=' + $PartitionNumber +
                '&file_path=' + $Folder
                try {
                    $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
                    $Response.virtual_disk_partition_files | ForEach-Object {
                        [PSCustomObject]@{
                            PSTypeName           = 'HPE.SimpliVity.File'
                            BackupId             = $BkpId
                            VirtualDisk          = $VirtualDisk
                            PartitionNumber      = $PartitionNumber
                            FileName             = $_.name
                            Directory            = [bool]$_.directory
                            SymbolicLink         = [bool]$_.symbolic_link
                            SizeMB               = '{0:n0}' -f ($_.size / 1mb)
                            LastModified         = ConvertFrom-SvtUtc -Date $_.last_modified
                            FileRestoreAvailable = [bool]$_.file_level_restore_available
                            RestorePath          = [PSCustomObject]@{
                                BackupId = $BkpId
                                Path     = "$VirtualDisk/$PartitionNumber$Folder"
                            }
                        }
                    }
                    continue
                }
                catch {
                    throw $_.Exception.Message
                }
            }

            # The user specifies virtual disk only. In this case, show the available partitions on the
            # virtual disk within the specified backup
            if ($PSBoundParameters.ContainsKey('VirtualDisk')) {
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/virtual_disk_partitions' +
                '?virtual_disk=' + $VirtualDisk
                try {
                    $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
                    $Response.partitions | ForEach-Object {
                        [PSCustomObject]@{
                            PSTypeName      = 'HPE.SimpliVity.Partition'
                            BackupId        = $BkpId
                            PartitionNumber = $_.partition_number
                            SizeMB          = '{0:n0}' -f ($_.size / 1mb)
                            DiskType        = $_.disk_type
                            Mountable       = [bool]$_.mountable
                        }
                    }
                    continue
                }
                catch {
                    throw $_.Exception.Message
                }
            }

            # The user does not specify any optional parameters. In this case show the available virtual disks
            # within the specified backup
            else {
                $Uri = $global:SvtConnection.VA + '/api/backups/' + $BkpId + '/virtual_disks'
                try {
                    $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
                    $Response.virtual_disks | ForEach-Object {
                        [PSCustomObject]@{
                            PSTypeName  = 'HPE.SimpliVity.VirtualDisk'
                            BackupId    = $BkpId
                            VirtualDisk = $_
                        }
                    }
                }
                catch {
                    throw $_.Exception.Message
                }
            }
        } # end foreach
    } #end process
}

<#
.SYNOPSIS
    Restore files from a SimpliVity backup to a specified virtual machine.
.DESCRIPTION
    This command will restore files from a backup into an ISO file that is then connected to the specified
    virtual machine.

    Notes:
    1. This command only works on backups taken from guests running Microsoft Windows.
    2. The target virtual machine must be running Microsoft Windows.
    3. The DVD drive on the target virtual machine must be disconnected, otherwise the restore will fail
    4. This command relies on the input from Get-SvtFile to pass in a valid backup file list to restore
    5. Whilst it is possible to use Get-SvtFile to list files in multiple backups, this command will only
       restore files from the first backup passed in. Files in subsequent backups are ignored, because only one
       DVD drive can be mounted on the target virtual machine.
    6. Folder size matters. The restore will fail if file sizes exceed a DVD capacity. When restoring a large
       amount of data, it might be faster to restore the entire virtual machine and recover the required files
       from the restored virtual disk.
    7. File level restores are restricted to nine virtual disks per virtual controller. When viewing the virtual
       disks with Get-SvtFile, you will only see the first nine disks if they are all attached to the same
       virtual controller. In this case, you must restore the entire VM and restore the required files from the
       restored virtual disk (VMDK) files.
.PARAMETER VmName
    The target virtual machine. Ensure the DVD drive is disconnected
.PARAMETER RestorePath
    An array containing the backup ID and the full path of the folder to restore. This consists of the virtual
    disk name, partition and folder name. The Get-SvtFile provides this parameter in the expected format,
    e.g. "/Win2019-01.vmdk/4/Users/Administrator/Documents".

.EXAMPLE
    PS C:\> $Backup = Get-SvtBackup -VmName Win2019-01 -Name 2020-04-26T18:00:00+10:10
    PS C:\> $File = $Backup | Get-SvtFile Win2019-01.vmdk 4 '/Log Files'
    PS C:\> $File | Restore-SvtFile -VmName Win2019-02

    The first command identifies the desired backup.
    The second command enumerates the files from the specified virtual disk, partition and file path in the backup
    The third command restores those files to an ISO and then connects this to the specified virtual machine.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Restore-SvtFile.md
#>
function Restore-SvtFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$VmName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [System.Object]$RestorePath
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $PrevBackupId = $null
        $FileList = @()

        try {
            $VMid = Get-SvtVm -VmName $VmName -ErrorAction Stop | Select-Object -ExpandProperty VMid
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($Restore in $RestorePath) {
            if (-Not $PrevBackupId) {
                $PrevBackupId = $Restore.BackupId
            }

            if ($Restore.BackupId -eq $PrevBackupId) {
                if ($Restore.Path -notin $FileList) {
                    $FileList += $Restore.Path
                }
            }
            else {
                Write-Warning 'Restore-SvtFile will only restore files from the first backup passed in'
            }
        }
    }

    end {
        $Uri = $global:SvtConnection.VA + '/api/backups/' + $Restore.BackupId + '/restore_files'
        $Body = @{
            'virtual_machine_id' = $VMid
            'paths'              = $FileList
        } | ConvertTo-Json
        Write-Verbose $Body

        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        [array]$AllTask += $Task
        $Task

        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

#endregion Backup

#region Datastore

<#
.SYNOPSIS
    Display HPE SimpliVity datastore information
.DESCRIPTION
    Shows datastore information from the SimpliVity Federation
.PARAMETER DatastoreName
    Show information for the specified datastore only
.EXAMPLE
    PS C:\> Get-SvtDatastore

    Shows all datastores in the Federation
.EXAMPLE
    PS C:\> Get-SvtDatastore -Name DS01 | Export-CSV Datastore.csv

    Writes the specified datastore information into a CSV file
.EXAMPLE
    PS C:\> Get-SvtDatastore DS01,DS02,DS03 | Select-Object Name, SizeGB, Policy

    Shows the specified properties for the HPE SimpliVity datastores
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Datastore
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastore.md
#>
function Get-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$DatastoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }
    $Uri = $global:SvtConnection.VA + '/api/datastores?show_optional_fields=true&case=insensitive'

    if ($PSBoundParameters.ContainsKey('DatastoreName')) {
        $Uri += "&name=$($DatastoreName -join ',')"
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('DatastoreName') -and $Response.Count -notmatch $DatastoreName.Count) {
        throw "At least 1 specified datastore name in '$DatastoreName' not found"
    }

    $Response.datastores | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.Datastore'
            SingleReplica            = $_.single_replica
            ClusterGroupIds          = $_.cluster_group_ids
            PolicyId                 = $_.policy_id
            MountDirectory           = $_.mount_directory
            CreateDate               = ConvertFrom-SvtUtc -Date $_.created_at
            PolicyName               = $_.policy_name
            ClusterName              = $_.omnistack_cluster_name
            Shares                   = $_.shares
            Deleted                  = $_.deleted
            HyperVisorId             = $_.hypervisor_object_id
            SizeGB                   = '{0:n0}' -f ($_.size / 1gb)
            DatastoreName            = $_.name
            DataCenterId             = $_.compute_cluster_parent_hypervisor_object_id
            DataCenterName           = $_.compute_cluster_parent_name
            HypervisorType           = $_.hypervisor_type
            DatastoreId              = $_.id
            ClusterId                = $_.omnistack_cluster_id
            HypervisorManagementIP   = $_.hypervisor_management_system
            HypervisorManagementName = $_.hypervisor_management_system_name
            HypervisorFreeSpaceGB    = '{0:n0}' -f ($_.hypervisor_free_space / 1gb)
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
.PARAMETER DatastoreName
    Specify the name of the new datastore
.PARAMETER ClusterName
    Specify the cluster of the new datastore
.PARAMETER PolicyName
    Specify the existing backup policy to assign to the new datastore
.PARAMETER SizeGB
    Specify the size of the new datastore in GB
.PARAMETER SingleReplica
    Specifies that the new datastore will be a single replica datastore (i.e. no high availability). This
    type of datastore is typically used where application based replication or HA is available. This parameter
    requires V4.1.0 or above.
.EXAMPLE
    PS C:\> New-SvtDatastore -DatastoreName ds01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 102400

    Creates a new 100TB datastore called ds01 on Cluster1 and assigns the pre-existing Daily backup policy to it
.EXAMPLE
    PS C:\> New-SvtDatastore -DatastoreName sr01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 200 -SingleReplica

    Creates a new 200GB single replica datastore called sr01.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtDatastore.md
#>
function New-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateRange(1, 1048576)]   # Max is 1024TB (matches the SimpliVity plugin limit)
        [System.int32]$SizeGB,

        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$SingleReplica

    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    $Uri = $global:SvtConnection.VA + '/api/datastores/'

    try {
        $ClusterId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
        Select-Object -ExpandProperty ClusterId

        $PolicyID = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('SingleReplica')) {
        $ReplicaSwitch = $true
    }
    else {
        $ReplicaSwitch = $false
    }

    $Body = @{
        'name'                 = $DatastoreName
        'omnistack_cluster_id' = $ClusterId
        'policy_id'            = $PolicyId
        'single_replica'       = $ReplicaSwitch
        'size'                 = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Remove an HPE SimpliVity datastore
.DESCRIPTION
    Removes the specified SimpliVity datastore. The datastore cannot be in use by any virtual machines.
.PARAMETER DatastoreName
    Specify the datastore to delete
.EXAMPLE
    PS C:\> Remove-SvtDatastore -Datastore DStemp
    PS C:\> Get-SvtTask

    Remove the datastore and monitor the task to ensure it completes successfully.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtDatastore.md
#>
function Remove-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw $($_.Exception.Message)
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Resize a HPE SimpliVity Datastore
.DESCRIPTION
    Resizes a specified datastore to the specified size in GB. The datastore size can be
    between 1GB and 1,048,576 GB (1,024TB).
.EXAMPLE
    PS C:\> Resize-SvtDatastore -DatastoreName ds01 -SizeGB 1024

    Resizes the specified datastore to 1TB
.PARAMETER DatastoreName
    Apply to specified datastore
.PARAMETER SizeGB
    The new total size of the datastore in GB
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Resize-SvtDatastore.md
#>
function Resize-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 1048576)] # Max is 1024TB (as per GUI)
        [System.Int32]$SizeGB
    )

    $Header = @{'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId + '/resize'
        $Body = @{ 'size' = $SizeGB * 1Gb } | ConvertTo-Json # Size must be in bytes
        Write-Verbose $Body
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Sets/changes the backup policy on a HPE SimpliVity Datastore
.DESCRIPTION
    A SimpliVity datastore must have a backup policy assigned to it. A default backup policy
    is assigned when a datastore is created. This command allows you to change the backup
    policy for the specified datastore
.PARAMETER DatastoreName
    Apply to specified datastore
.PARAMETER PolicyName
    The new backup policy for the specified datastore
.EXAMPLE
    PS C:\> Set-SvtDatastorePolicy -DatastoreName ds01 -PolicyName Weekly

    Assigns a new backup policy to the specified datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtDatastorePolicy.md
#>
function Set-SvtDatastorePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    try {
        $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId + '/set_policy'

        $PolicyId = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
        Select-Object -ExpandProperty PolicyId -Unique

        $Body = @{ 'policy_id' = $PolicyId } | ConvertTo-Json
        Write-Verbose $Body
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Adds a share to a HPE SimpliVity datastore for a compute node (a standard ESXi host)
.DESCRIPTION
    Adds a share to a HPE SimpliVity datastore for a specified compute node
.PARAMETER DatastoreName
    The datastore to add a new share to
.PARAMETER ComputeNodeName
    The compute node that will have the new share
.EXAMPLE
    PS C:\> Publish-SvtDatastore -DatastoreName DS01 -ComputeNodeName ESXi03

    The specified compute node is given access to the datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Publish-SvtDatastore.md
#>
function Publish-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }

    try {
        $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId + '/share'
        $Body = @{ 'host_name' = $ComputeNodeName } | ConvertTo-Json
        Write-Verbose $Body
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Removes a share from a HPE SimpliVity datastore for a compute node (a standard ESXi host)
.DESCRIPTION
    Removes a share from a HPE SimpliVity datastore for a specified compute node
.PARAMETER DatastoreName
    The datastore to remove a share from
.PARAMETER ComputeNodeName
    The compute node that will no longer have access
.EXAMPLE
    PS C:\> Unpublish-SvtDatastore -DatastoreName DS01 -ComputeNodeName ESXi01

    The specified compute node will no longer have access to the datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Unpublish-SvtDatastore.md
#>
function Unpublish-SvtDatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }

    $Body = @{ 'host_name' = $ComputeNodeName } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId + '/unshare'
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask # Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Displays the compute hosts (standard ESXi hosts) that have access to the specified datastore(s)
.DESCRIPTION
    Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS
.PARAMETER DatastoreName
    Specify the datastore to display information for
.EXAMPLE
    PS C:\> Get-SvtDatastoreComputeNode -DatastoreName DS01

    Display the compute nodes that have NFS access to the specified datastore
.EXAMPLE
    PS C:\> Get-SvtDatastoreComputeNode

    Displays all datastores in the Federation and the compute nodes that have NFS access to them
.INPUTS
    System.String
    HPE.SimpliVity.Datastore
.OUTPUTS
    HPE.SimpliVity.ComputeNode
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
#>
function Get-SvtDatastoreComputeNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$DatastoreName = (Get-SvtDatastore | Select-Object -ExpandProperty DatastoreName)
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }
    }

    process {
        foreach ($ThisDatastore in $DatastoreName) {
            try {
                $DatastoreId = Get-SvtDatastore -DatastoreName $ThisDatastore -ErrorAction Stop |
                Select-Object -ExpandProperty DatastoreId

                $Uri = $global:SvtConnection.VA + '/api/datastores/' + $DatastoreId + '/standard_hosts'
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.standard_hosts | ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName         = 'HPE.SimpliVity.ComputeNode'
                    DatastoreName      = $ThisDatastore
                    HypervisorObjectId = $_.hypervisor_object_id
                    ComputeNodeIp      = $_.ip_address
                    ComputeNodeName    = $_.name
                    Shared             = $_.shared
                    VmCount            = $_.virtual_machine_count
                }
            }
        } #end foreach datastore
    } # end process
}

<#
.SYNOPSIS
    Displays information on the available external datastores configured in HPE SimpliVity
.DESCRIPTION
    Displays external stores that have been registered. Upon creation, external datastores are associated
    with a specific SimpliVity cluster, but are subsequently available to all clusters in the cluster group
    to which the specified cluster is a member.

    External Stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped
    backups to HPE SimpliVity.
.PARAMETER ExternalStoreName
    Specify the external datastore to display information
.EXAMPLE
    PS C:\> Get-SvtExternalStore StoreOnce-Data01,StoreOnce-Data02,StoreOnce-Data03
    PS C:\> Get-SvtExternalStore -Name StoreOnce-Data01

    Display information about the specified external datastore(s)
.EXAMPLE
    PS C:\> Get-SvtExternalStore

    Displays all external datastores in the Federation
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Externalstore
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command works with HPE SimpliVity 4.0.0 and above
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtExternalStore.md
#>
function Get-SvtExternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$ExternalStoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SvtConnection.VA + '/api/external_stores?case=insensitive'
    if ($PSBoundParameters.ContainsKey('ExternalstoreName')) {
        $Uri += "&name=$($ExternalstoreName -join ',')"
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ExternalStoreName') -and
        $Response.Count -notmatch $ExternalStoreName.Count) {
        throw "At least 1 specified external datastore name in '$ExternalStoreName' not found"
    }

    $Response.external_stores | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName         = 'HPE.SimpliVity.ExternalStore'
            ClusterGroupIds    = $_.cluster_group_ids
            ManagementIP       = $_.management_ip
            ManagementPort     = $_.management_port
            ExternalStoreName  = $_.name
            StoragePort        = $_.storage_port
            OmniStackClusterID = $_.omnistack_cluster_id
            Type               = $_.type
        }
    }
}

<#
.SYNOPSIS
    Registers a new external datastore with the specified HPE SimpliVity cluster
.DESCRIPTION
    Registers an external datastore. Upon creation, external datastores are associated with a specific
    HPE SimpliVity cluster, but are subsequently available to all clusters in the cluster group to which
    the specified cluster is a member.

    External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped
    backups to HPE SimpliVity. The external datastore must be created and configured appropriately to allow
    the registration to successfully complete.
.PARAMETER ExternalStoreName
    External datastore name. This is the pre-existing Catalyst store name on HPE StoreOnce
.PARAMETER ClusterName
    The HPE SimpliVity cluster name to associate this external store. Once created, the external store is
    available to all clusters in the cluster group
.PARAMETER ManagementIP
    The IP Address of the external store appliance
.PARAMETER Username
    The username associated with the external datastore. HPE SimpliVity uses this to authenticate and
    access the external datastore
.PARAMETER Userpass
    The password for the specified username
.PARAMETER ManagementPort
    The management port to use for the external storage appliance
.PARAMETER StoragePort
    The storage port to use for the external storage appliance
.EXAMPLE
    PS C:\> New-SvtExternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SvtCluster
        -ManagementIP 192.168.10.202 -Username SVT_service -Userpass Password123

    Registers a new external datastore called StoreOnce-Data03 with the specified HPE SimpliVity Cluster,
    using preconfigured credentials.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command works with HPE SimpliVity 4.0.0 and above
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtExternalStore.md
#>
function New-SvtExternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$ExternalStoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$ManagementIP,

        [Parameter(Mandatory = $true, Position = 3)]
        [System.String]$Username,

        [Parameter(Mandatory = $true, Position = 4)]
        [System.String]$Userpass,

        [Parameter(Mandatory = $false, Position = 5)]
        [System.Int32]$ManagementPort = 9387,

        [Parameter(Mandatory = $false, Position = 6)]
        [System.Int32]$StoragePort = 9388
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }

    $Uri = $global:SvtConnection.VA + '/api/external_stores'

    try {
        $ClusterId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
        Select-Object -ExpandProperty ClusterId
    }
    catch {
        throw $_.Exception.Message
    }

    $Body = @{
        'management_ip'        = $ManagementIP
        'management_port'      = $ManagementPort
        'name'                 = $ExternalStoreName
        'omnistack_cluster_id' = $ClusterID
        'password'             = $Userpass
        'storage_port'         = $StoragePort
        'username'             = $Username
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used

}

<#
.SYNOPSIS
    Deregister (remove) an external datastore from the specified HPE SimpliVity cluster
.DESCRIPTION
    Deregister an external datastore. Removes the external store as a backup destination for the cluster.
    Backups remain on the external store, but they can no longer be managed by HPE SimpliVity.

    External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped
    backups to HPE SimpliVity. Once deregistered, the Catalyst store remains on the StoreOnce appliance but
    is inaccessible to HPE SimpliVity.
.PARAMETER ExternalStoreName
    External datastore name. This is the pre-existing Catalyst store name on HPE StoreOnce
.PARAMETER ClusterName
    The HPE SimpliVity cluster name to associate this external store. Once created, the external store is
    available to all clusters in the cluster group
.EXAMPLE
    PS C:\> Remove-SvtExternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SvtCluster

    Deregister (remove) the external datastore called StoreOnce-Data03 from the specified
    HPE SimpliVity Cluster
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command works with HPE SimpliVity 4.0.1 and above
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtExternalStore.md
#>
function Remove-SvtExternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$ExternalStoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.15+json'
    }

    $Uri = $global:SvtConnection.VA + '/api/external_stores/unregister'

    try {
        $ClusterId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
        Select-Object -ExpandProperty ClusterId

        $Body = @{
            'name'                 = $ExternalStoreName
            'omnistack_cluster_id' = $ClusterID
        } | ConvertTo-Json
        Write-Verbose $Body

        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Updates the IP address and credentials for the external store appliance (HPE StoreOnce)
.DESCRIPTION
    Updates an existing registered external store with new management IP and credentials. This command
    should be used if the credentials on the StoreOnce appliance are changed.

    External Stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped
    backups to HPE SimpliVity.
.PARAMETER ExternalStoreName
    External datastore name. This is the pre-existing Catalyst store name on HPE StoreOnce
.PARAMETER ManagementIP
    The IP Address of the external store appliance
.PARAMETER Username
    The username associated with the external datastore. HPE SimpliVity uses this to authenticate and
    access the external datastore
.PARAMETER Userpass
    The password for the specified username
.EXAMPLE
    PS C:\> Set-SvtExternalStore -ExternalstoreName StoreOnce-Data03 -ManagementIP 192.168.10.202
        -Username SVT_service -Userpass Password123

    Resets the external datastore credentials and management IP address
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    This command works with HPE SimpliVity 4.0.1 and above
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtExternalStore.md
#>
function Set-SvtExternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$ExternalStoreName,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$ManagementIP,

        [Parameter(Mandatory = $true, Position = 3)]
        [System.String]$Username,

        [Parameter(Mandatory = $true, Position = 4)]
        [System.String]$Userpass
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.15+json'
    }

    $Uri = $global:SvtConnection.VA + '/api/external_stores/update_credentials'

    $Body = @{
        'management_ip' = $ManagementIP
        'name'          = $ExternalStoreName
        'password'      = $Userpass
        'username'      = $Username
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

#endregion Datastore

#region Host

<#
.SYNOPSIS
    Display HPE SimpliVity host information
.DESCRIPTION
    Shows host information from the SimpliVity Federation.

    Free Space is shown in green if at least 20% of the allocated storage is free,
    yellow if free space is between 10% and 20% and red if less than 10% is free.
.PARAMETER HostName
    Show the specified host only
.PARAMETER ClusterName
    Show hosts from the specified SimpliVity cluster only
.EXAMPLE
    PS C:\> Get-SvtHost

    Shows all hosts in the Federation
.EXAMPLE
    PS C:\> Get-SvtHost -Name Host01
    PS C:\> Get-SvtHost Host01,Host02

    Shows the specified host(s)
.EXAMPLE
    PS C:\> Get-SvtHost -ClusterName MyCluster

    Shows hosts in specified HPE SimpliVity cluster(s)
.EXAMPLE
    PS C:\> Get-SvtHost | Where-Object DataCenter -eq MyDC | Format-List *

    Shows all properties for all hosts in the specified Datacenter
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Host
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtHost.md
#>
function Get-SvtHost {
    [CmdletBinding(DefaultParameterSetName = 'ByHostName')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByHostName')]
        [Alias('Name')]
        [System.String[]]$HostName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [System.String[]]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }
    # Updated to support older (than 3.7.5) versions of SimpliVity. case=insensitive not supported for host object
    $Uri = $global:SvtConnection.VA + '/api/hosts?show_optional_fields=true&sort=name&order=ascending'

    if ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $FQDN = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            $Uri += "&name=$($FQDN -join ',')"
        }
        catch {
            throw $_.Exception.Message
        }
    }

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&compute_cluster_name=$($ClusterName -join ',')"
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ClusterName') -and -not $Response.hosts.name) {
        throw "Specified cluster(s) $ClusterName not found"
    }

    $Response.hosts | Foreach-Object {
        [PSCustomObject]@{
            PSTypeName                = 'HPE.SimpliVity.Host'
            ClusterFeatureLevel       = $_.cluster_feature_level
            PolicyEnabled             = $_.policy_enabled
            HypervisorClusterId       = $_.compute_cluster_hypervisor_object_id
            StorageMask               = $_.storage_mask
            PotentialFeatureLevel     = $_.potential_feature_level
            Type                      = $_.type
            CurrentFeatureLevel       = $_.current_feature_level
            ClusterId                 = $_.omnistack_cluster_id
            HypervisorId              = $_.hypervisor_object_id
            ClusterName               = $_.compute_cluster_name
            ManagementIP              = $_.management_ip
            FederationIP              = $_.federation_ip
            VirtualControllerName     = $_.virtual_controller_name
            FederationMask            = $_.federation_mask
            Model                     = $_.model
            DataCenterId              = $_.compute_cluster_parent_hypervisor_object_id
            HostId                    = $_.id
            StorageMTU                = $_.storage_mtu
            State                     = $_.state
            UpgradeState              = $_.upgrade_state
            FederationMTU             = $_.federation_mtu
            CanRollback               = $_.can_rollback
            StorageIP                 = $_.storage_ip
            ClusterGroupIds           = $_.cluster_group_ids
            ManagementMTU             = $_.management_mtu
            Version                   = $_.version
            HostName                  = $_.name
            DataCenterName            = $_.compute_cluster_parent_name
            HypervisorManagementIP    = $_.hypervisor_management_system
            ManagementMask            = $_.management_mask
            HypervisorManagementName  = $_.hypervisor_management_system_name
            Date                      = ConvertFrom-SvtUtc -Date $_.date
            UsedLogicalCapacityGB     = '{0:n0}' -f ($_.used_logical_capacity / 1gb)
            UsedCapacityGB            = '{0:n0}' -f ($_.used_capacity / 1gb)
            CompressionRatio          = $_.compression_ratio
            StoredUnCompressedDataGB  = '{0:n0}' -f ($_.stored_uncompressed_data / 1gb)
            StoredCompressedDataGB    = '{0:n0}' -f ($_.stored_compressed_data / 1gb)
            EfficiencyRatio           = $_.efficiency_ratio
            DeduplicationRatio        = $_.deduplication_ratio
            LocalBackupCapacityGB     = '{0:n0}' -f ($_.local_backup_capacity / 1gb)
            CapacitySavingsGB         = '{0:n0}' -f ($_.capacity_savings / 1gb)
            AllocatedCapacityGB       = '{0:n0}' -f ($_.allocated_capacity / 1gb)
            StoredVmDataGB            = '{0:n0}' -f ($_.stored_virtual_machine_data / 1gb)
            RemoteBackupCapacityGB    = '{0:n0}' -f ($_.remote_backup_capacity / 1gb)
            FreeSpaceGB               = '{0:n0}' -f ($_.free_space / 1gb)
            AvailabilityZoneEffective = $_.availability_zone_effective
            AvailabilityZonePlanned   = $_.availability_zone_planned
        }
    }

    if (-not $PSBoundParameters.ContainsKey('HostName') -and -not $PSBoundParameters.ContainsKey('ClusterName')) {
        if ($global:SvtHost) {
            Write-Verbose "Update global variable SvtHost with a list of hostnames and id's"
        }
        else {
            Write-Verbose "Create global variable SvtHost with a list of hostnames and id's"
        }
        $global:SvtHost = $Response.hosts | Foreach-Object {
            [PSCustomObject]@{
                HostName = $_.name
                HostId   = $_.id
            }
        }
    }
}

<#
.SYNOPSIS
    Display HPE SimpliVity host hardware information
.DESCRIPTION
    Shows host hardware information for the specified host(s). Some properties are
    arrays, from the REST API response. Information in these properties can be enumerated as
    usual. See examples for details.
.PARAMETER HostName
    Show information for the specified host only
.EXAMPLE
    PS C:\> Get-SvtHardware -HostName Host01 | Select-Object -ExpandProperty LogicalDrives

    Enumerates all of the logical drives from the specified host
.EXAMPLE
    PS C:\> (Get-SvtHardware Host01).RaidCard

    Enumerate all of the RAID cards from the specified host
.EXAMPLE
    PC C:\> Get-SvtHardware Host1,Host2,Host3

    Shows hardware information for all hosts in the specified list
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Hardware
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtHardware.md
#>
function Get-SvtHardware {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }

        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $global:SvtHost.HostName
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            $HostId = ($global:SvtHost | Where-Object HostName -eq $Thishost).HostId
            $Uri = $global:SvtConnection.VA + '/api/hosts/' + $HostId + '/hardware'

            try {
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.host | ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName       = 'HPE.SimpliVity.Hardware'
                    HostName         = $_.name
                    HostId           = $_.host_id
                    SerialNumber     = $_.serial_number
                    Manufacturer     = $_.manufacturer
                    Model            = $_.model_number
                    FirmwareRevision = $_.firmware_revision
                    Status           = $_.status
                    RaidCard         = $_.raid_card
                    Battery          = $_.battery
                    AcceleratorCard  = $_.accelerator_card
                    LogicalDrives    = $_.logical_drives
                }
            }
        } # end foreach
    } # end process
}

<#
.SYNOPSIS
    Display HPE SimpliVity physical disk information
.DESCRIPTION
    Shows physical disk information for the specified host(s). This includes the
    installed storage kit, which is not provided by the API, but it derived from
    the host model, the number of disks and the disk capacities.
.PARAMETER HostName
    Show information for the specified host only
.EXAMPLE
    PS C:\> Get-SvtDisk

    Shows physical disk information for all SimpliVity hosts in the federation.
.EXAMPLE
    PS C:\> Get-SvtDisk -HostName Host01

    Shows physical disk information for the specified SimpliVity host.
.EXAMPLE
    PS C:\> Get-SvtDisk -HostName Host01 | Select-Object -First 1 | Format-List

    Show all of the available information about the first disk on the specified host.
.EXAMPLE
    PC C:\> Get-SvtHost -Cluster PROD | Get-SvtDisk

    Shows physical disk information for all hosts in the specified cluster.
.EXAMPLE
    PC C:\> Get-SvtHost Host1,Host2,Host3 | Get-SvtDisk

    Shows physical disk information for all hosts in the specified list
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Disk
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDisk.md
#>
function Get-SvtDisk {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $LocalCulture = Get-Culture #[System.Threading.Thread]::CurrentThread.CurrentCulture

        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $global:SvtHost.HostName
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            $Hardware = Get-SvtHardware -HostName $Thishost

            # We MUST sort by slot number to ensure SSDs are at the top to properly support 380 H
            # This command removes duplicates - all models have at least two logical disks where physical
            # disks would otherwise appear twice in the collection.
            $Disk = $Hardware.logicaldrives.drive_sets.physical_drives |
            Sort-Object { [system.Int32]($_.Slot -replace '(\d+).*', '$1') } | Get-Unique -AsString

            # Check capacity of first disk in collection (works ok all most models - 380 H included, for now)
            $DiskCapacity = [int][math]::Ceiling(($Disk | Select-Object -First 1).capacity / 1TB)
            $DiskCount = ($Disk | Measure-Object).Count

            $SvtModel = Get-SvtModel | Where-Object {
                $Hardware.Model -match $_.Model -and
                $DiskCount -eq $_.DiskCount -and
                $DiskCapacity -eq $_.DiskCapacity
            }

            if ($SvtModel) {
                $Kit = $SvtModel.StorageKit
            }
            else {
                $Kit = 'Unknown Storage Kit'
            }

            $Disk | ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName       = 'HPE.SimpliVity.Disk'
                    SerialNumber     = $_.serial_number
                    Manufacturer     = $_.manufacturer
                    ModelNumber      = $_.model_number
                    Firmware         = $_.firmware_revision
                    Status           = $_.status
                    Health           = $_.health
                    Enclosure        = [System.Int32]$_.enclosure
                    Slot             = [System.Int32]$_.slot
                    CapacityTB       = [single]::Parse('{0:n2}' -f ($_.capacity / 1000000000000), $LocalCulture)
                    WWN              = $_.wwn
                    PercentRebuilt   = [System.Int32]$_.percent_rebuilt
                    AdditionalStatus = $_.additional_status
                    MediaType        = $_.media_type
                    DrivePosition    = $_.drive_position
                    RemainingLife    = $_.life_remaining
                    HostStorageKit   = $Kit
                    HostName         = $ThisHost
                }
            } # end foreach disk
        } #end foreach host
    } #end process
}

<#
.SYNOPSIS
    Display capacity information for the specified SimpliVity host
.DESCRIPTION
    Displays capacity information for a number of useful metrics, such as free space, used capacity, compression
    ratio and efficiency ratio over time for a specified SimpliVity host.
.PARAMETER HostName
    The SimpliVity host you want to show capacity information for
.PARAMETER OffsetHour
    Offset in hours from now
.PARAMETER Hour
    The range in hours (the duration from the specified point in time)
.PARAMETER Resolution
    The resolution in seconds, minutes, hours or days
.PARAMETER Chart
    Create a chart from capacity information. If more than one host is passed in, a chart for each host is created
.EXAMPLE
    PS C:\> Get-SvtCapacity MyHost

    Shows capacity information for the specified host for the last 24 hours
.EXAMPLE
    PS C:\> Get-SvtCapacity -HostName MyHost -Hour 1 -Resolution MINUTE

    Shows capacity information for the specified host showing every minute for the last hour
.EXAMPLE
    PS C:\> Get-SvtCapacity -Chart

    Creates a chart for each host in the SimpliVity federation showing the latest (24 hours) capacity details
.EXAMPLE
    PC C:\> Get-SvtCapacity Host1,Host2,Host3

    Shows capacity information for all hosts in the specified list
.INPUTS
    System.String
    HPESimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Capacity
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCapacity.md
#>
function Get-SvtCapacity {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string[]]$HostName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$Hour = 24,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'HOUR',

        [Parameter(Mandatory = $false, Position = 3)]
        [System.Int32]$OffsetHour = 0,

        [Parameter(Mandatory = $false)]
        [Switch]$Chart
    )

    begin {
        #$VerbosePreference = 'Continue'

        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
        }
        $Range = $Hour * 3600
        $Offset = $OffsetHour * 3600

        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $global:SvtHost.HostName
        }

        if ($Resolution -eq 'SECOND' -and $Range -gt 43200 ) {
            throw "Maximum range value for resolution $resolution is 12 hours"
        }
        elseif ($Resolution -eq 'MINUTE' -and $Range -gt 604800 ) {
            throw "Maximum range value for resolution $resolution is 168 hours (1 week)"
        }
        elseif ($Resolution -eq 'HOUR' -and $Range -gt 5184000 ) {
            throw "Maximum range value for resolution $resolution is 1,440 hours (2 months)"
        }
        elseif ($Resolution -eq 'DAY' -and $Range -gt 94608000 ) {
            throw "Maximum range value for resolution $resolution is 26,280 hours (3 years)"
        }

        if ($Resolution -eq 'SECOND' -and $Range -gt 3600 ) {
            $Message = 'Using the resolution of SECOND beyond a range of 1 hour can take a long time to complete'
            Write-Warning $Message
        }
        if ($Resolution -eq 'MINUTE' -and $Range -gt 43200 ) {
            $Message = 'Using the resolution of MINUTE beyond a range of 12 hours can take a long time to complete'
            Write-Warning $Message
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            $HostId = ($global:SvtHost | Where-Object HostName -eq $Thishost).HostId

            $Uri = $global:SvtConnection.VA + '/api/hosts/' + $HostId + '/capacity?time_offset=' +
            $Offset + '&range=' + $Range + '&resolution=' + $Resolution

            try {
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This returns each Metric with a date and value
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = ($_.name -split '_' |
                    ForEach-Object {
                        (Get-Culture).TextInfo.ToTitleCase($_)
                    }
                ) -join ''

                $_.data_points | ForEach-Object {
                    [PSCustomObject] @{
                        Name  = $MetricName
                        Date  = ConvertFrom-SvtUtc -Date $_.date
                        Value = $_.value
                    }
                }
            }

            # Transpose the custom object to return each date with the value for each metric
            # NOTE: PowerShell Core displays grouped items out of order, so sort again by Name
            $CapacityObject = $CustomObject | Sort-Object -Property { $_.Date -as [datetime] } |
            Group-Object -Property Date | Sort-Object -Property { $_.Name -as [datetime] } |
            ForEach-Object {
                $Property = [ordered]@{
                    PSTypeName = 'HPE.SimpliVity.Capacity'
                    Date       = $_.Name
                }
                $_.Group | Foreach-object {
                    if ($_.Name -match 'Ratio') {
                        $Property += @{
                            "$($_.Name)" = '{0:n2}' -f $_.Value
                        }
                    }
                    else {
                        $Property += @{
                            "$($_.Name)" = $_.Value
                        }
                    }
                }
                $Property += @{ HostName = $Thishost }
                New-Object -TypeName PSObject -Property $Property
            }

            if ($PSBoundParameters.ContainsKey('Chart')) {
                $ChartObject += $CapacityObject
            }
            else {
                $CapacityObject
            }
        } #end foreach host
    }

    end {
        if ($PSBoundParameters.ContainsKey('Chart')) {
            Get-SvtCapacityChart -Capacity $ChartObject
        }
    }
}

<#
.SYNOPSIS
    Removes a HPE SimpliVity node from the cluster/federation
.DESCRIPTION
    Removes a HPE SimpliVity node from the cluster/federation. Once this command is executed, the specified
    node must be factory reset and can then be redeployed using the Deployment Manager. This command is
    equivalent GUI command "Remove from federation"

    If there are any virtual machines running on the node or if the node is not HA-compliant, this command
    will fail. You can specify the force command, but be aware that this could cause data loss.
.PARAMETER HostName
    Specify the node to remove.
.PARAMETER Force
    Forces removal of the node from the HPE SimpliVity federation. THIS CAN CAUSE DATA LOSS. If there is one
    node left in the cluster, this parameter must be specified (removes HA compliance for any VMs in the
    affected cluster.)
.EXAMPLE
    PS C:\> Remove-SvtHost -HostName Host01

    Removes the node from the federation providing there are no VMs running and providing the
    node is HA-compliant.
.EXAMPLE
    PS C:\> Remove-SvtHost -HostName Host01 -Force

    Forcibly removes the host from the federation. This command may cause data loss
.EXAMPLE
    PS C:\> Remove-SvtHost -HostName Host01 -WhatIf

    This command provides a report on the intended action only, without actually performing the host removal.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtHost.md
#>
function Remove-SvtHost {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$HostName,

        [switch]$Force
    )

    # V4.0.0 states this is now application/vnd.simplivity.v1.14+json,
    # but there don't appear to be any new features
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    try {
        $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
        $HostId = $global:SvtHost | Where-Object HostName -eq $HostName | Select-Object -ExpandProperty HostId
        $Uri = $global:SvtConnection.VA + '/api/hosts/' + $HostId + '/remove_from_federation'
    }
    catch {
        throw $_.Exception.Message
    }

    $ForceHostRemoval = $false
    if ($PSBoundParameters.ContainsKey('Force')) {
        $ForceHostRemoval = $true
    }

    $Body = @{ 'force' = $ForceHostRemoval } | ConvertTo-Json
    Write-Verbose $Body

    if ($PSCmdlet.ShouldProcess("$HostName", "Remove host")) {
        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SvtTask = $Task
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Shutdown a HPE SimpliVity Virtual Appliance
.DESCRIPTION
    Ideally, you should only run this command when all the VMs in the cluster
    have been shutdown, or if you intend to leave virtual controllers running in the cluster.

    This RESTAPI call only works if executed on the local host to the virtual controller. So this command
    connects to the virtual controller on the specified host to shut it down.

    Note: Once the shutdown is executed on the specified host, this command will reconnect to another
    operational virtual controller in the Federation, using the same credentials, if there is one.
.PARAMETER HostName
    Specify the host name running the SimpliVity Virtual Appliance to shutdown
.EXAMPLE
    PS C:\> Start-SvtShutdown -HostName <Name of SimpliVity host>

    if not the last operational virtual controller, this command waits for the affected VMs to be HA
    compliant. If it is the last virtual controller, the shutdown does not wait for HA compliance.

    You will be prompted before the shutdown. If this is the last virtual controller, ensure all virtual
    machines are powered off, otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SvtShutdown -HostName Host01 -Confirm:$false

    Shutdown the specified virtual controller without confirmation. If this is the last virtual controller,
    ensure all virtual machines are powered off, otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SvtShutdown -HostName Host01 -WhatIf -Verbose

    Reports on the shutdown operation, including connecting to the virtual controller, without actually
    performing the shutdown.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Start-SvtShutdown.md
#>
function Start-SvtShutdown {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHostName')]
        [System.String]$HostName
    )

    $VerbosePreference = 'Continue'
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    try {
        $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
        # We get hosts here rather than using $SvtHost variable because we need state of SVA and cluster name
        # SVA state on target (and other) hosts is likely to be changing during shutdown activities.   
        $AllHost = Get-SvtHost -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $ThisHost = $Allhost | Where-Object HostName -eq $HostName
    $ThisCluster = $ThisHost | Select-Object -First 1 -ExpandProperty Clustername

    # display current SVA state for all hosts in the target cluster
    $Allhost | Where-Object ClusterName -eq $ThisCluster | ForEach-Object {
        Write-Verbose "Current state of host $($_.HostName) in cluster $ThisCluster is $($_.State)"
    }

    # so we can reconnect to another SVA in the federation afterwards, if any
    $NextHost = $Allhost | Where-Object { $_.HostName -ne $HostName -and $_.State -eq 'ALIVE' } |
    Select-Object -First 1

    $LiveHostCount = $Allhost | Where-Object { $_.ClusterName -eq $ThisCluster -and $_.State -eq 'ALIVE' } |
    Measure-Object | Select-Object -ExpandProperty Count

    # exit if the SVA is already off
    if ($ThisHost.State -ne 'ALIVE') {
        $ThisHost.State
        throw "The HPE SimpliVity Virtual Appliance on $($ThisHost.HostName) is not running"
    }

    if ($NextHost) {
        $Message = "This command will reconnect to $($NextHost.HostName) following the shutdown of the " +
        "SimpliVity Virtual Appliance on $($ThisHost.HostName)"
        Write-Verbose $Message
    }
    else {
        $Message = 'This is the last operational SimpliVity Virtual Appliance in the federation, ' +
        'reconnect not possible'
        Write-Verbose $Message
    }

    # Connect to the target virtual controller, using the existing credentials saved to $SvtConnection
    try {
        Write-Verbose "Connecting to $($ThisHost.VirtualControllerName) on host $($ThisHost.HostName)..."
        $null = Connect-Svt -VirtualAppliance $ThisHost.ManagementIP -Credential $SvtConnection.Credential -ErrorAction Stop
        Write-Verbose "Successfully connected to $($ThisHost.VirtualControllerName) on host $($ThisHost.HostName)"
    }
    catch {
        throw $_.Exception.Message
    }

    # Confirm if this is the last running virtual controller in this cluster
    Write-Verbose "$LiveHostCount operational HPE SimpliVity Virtual Appliance(s) in the $ThisCluster cluster"
    if ($LiveHostCount -lt 2) {
        Write-Warning "This is the last SimpliVity Virtual Appliance running in the $ThisCluster cluster"
        $Message = 'Using this command with confirm turned off could result in loss of data if you have ' +
        'not already powered off all virtual machines'
        Write-Warning $Message
    }

    # Only execute the command if confirmed. Using -WhatIf will report only
    if ($PSCmdlet.ShouldProcess("$($ThisHost.HostName)", "Shutdown virtual controller in cluster $ThisCluster")) {
        try {
            $Uri = $global:SvtConnection.VA + '/api/hosts/' + $ThisHost.HostId + '/shutdown_virtual_controller'
            $Body = @{ 'ha_wait' = $true } | ConvertTo-Json
            Write-Verbose $Body
            $null = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        if ($LiveHostCount -le 1) {
            Write-Verbose 'Sleeping 10 seconds before issuing final shutdown...'
            Start-Sleep -Seconds 10

            try {
                # Instruct the shutdown task running on the last virtual controller in the cluster not to
                # wait for HA compliance
                $Body = @{'ha_wait' = $false } | ConvertTo-Json
                Write-Verbose $Body
                $null = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Message = "Shutting down the last virtual controller in the $ThisCluster cluster " +
            "now ($($ThisHost.HostName))"
            Write-Output $Message
        }

        if ($NextHost) {
            try {
                Write-Verbose "Reconnecting to $($NextHost.VirtualControllerName) on $($NextHost.HostName)..."
                Connect-Svt -VirtualAppliance $NextHost.ManagementIP -Credential $SvtConnection.Credential `
                    -ErrorAction Stop | Out-Null

                $Message = "Successfully reconnected to $($NextHost.VirtualControllerName) " +
                "on $($NextHost.HostName)"
                Write-Verbose $Message

                $SvaRunning = $true
                $Message = 'Wait to allow the storage IP to failover to an operational virtual controller. ' +
                'This may take a long time if the host is running virtual machines.'
                Write-Verbose $Message
                do {
                    $Message = 'Waiting 30 seconds, do not issue additional shutdown commands until this ' +
                    'operation completes...'
                    Write-verbose $Message
                    Start-Sleep -Seconds 30

                    $SvaState = Get-SvtHost -HostName $($ThisHost.HostName) -ErrorAction Stop |
                    Select-Object -ExpandProperty State

                    if ($SvaState -eq 'FAULTY') {
                        $SvaRunning = $false
                    }
                } while ($SvaRunning)

                Write-Output "Successfully shutdown the virtual controller on $($ThisHost.HostName)"
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $Message = 'This was the last operational HPE SimpliVity Virtual Appliance in the Federation, ' +
            'reconnect not possible'
            Write-Verbose $Message
        }
    } #endif should process
}

<#
.SYNOPSIS
    Get the shutdown status of one or more SimpliVity Virtual Appliances
.DESCRIPTION
    This cmdlet iterates through the specified hosts and connects to each SVA sequentially.

    The RESTAPI call only works if status is 'None' (i.e. the SVA is responsive). However, this cmdlet is
    still useful to identify the unresponsive SVAs (i.e. shut down or shutting down).

    Note, the RESTAPI only supports confirmation of the local SVA, so the cmdlet must connect to each SVA.
    The connection token will therefore point to the last SVA we successfully connect to. You may want to
    reconnect to your preferred SVA again using Connect-Svt.
.PARAMETER HostName
    Show shutdown status for the specified host only
.EXAMPLE
    PS C:\> Get-SvtShutdownStatus

    Connect to all SVAs in the Federation and show their shutdown status
.EXAMPLE
    PS C:\> Get-SvtShutdownStatus -HostName <Name of SimpliVity host>

.EXAMPLE
    PS C:\> Get-SvtHost -Cluster MyCluster | Get-SvtShutdownStatus

    Shows all shutdown status for all the SVAs in the specified cluster
    HostName is passed in from the pipeline, using the property name
.EXAMPLE
    PS C:\> '10.10.57.59','10.10.57.61' | Get-SvtShutdownStatus

    HostName is passed in them the pipeline by value. Same as:
    Get-SvtShutdownStatus -HostName '10.10.57.59','10.10.57.61'
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtShutdownStatus.md
#>
function Get-SvtShutdownStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.1+json'
        }

        $Allhost = Get-SvtHost
        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $global:SvtHost.HostName
        }
    }

    process {
        foreach ($ThisHostName in $HostName) {
            $ThisHost = $Allhost | Where-Object HostName -eq $ThisHostName

            try {
                Connect-Svt -VirtualAppliance $ThisHost.ManagementIP -Credential $SvtConnection.Credential -ErrorAction Stop |
                Out-Null

                Write-Verbose $SvtConnection
            }
            catch {
                $Message = "The virtual controller $($ThisHost.ManagementName) on " +
                "host $ThisHostName is not responding"
                Write-Error $Message
                continue
            }

            try {
                $Uri = $global:SvtConnection.VA + '/api/hosts/' + $ThisHost.HostId +
                '/virtual_controller_shutdown_status'
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                $Message = "Error connecting to $($ThisHost.ManagementIP) (host $ThisHostName). " +
                'Check that it is running'
                Write-Error $Message
                continue
            }

            $Response.shutdown_status | ForEach-Object {
                [PSCustomObject]@{
                    HostName              = $ThisHostName
                    VirtualControllerName = $ThisHost.VirtualControllerName
                    ManagementIP          = $ThisHost.ManagementIP
                    ShutdownStatus        = $_.Status
                }
            }
        } #end foreach hostname
    } #end process
}

<#
.SYNOPSIS
    Cancel the previous shutdown command for one or more SimpliVity Virtual Appliances
.DESCRIPTION
    Cancels a previously executed shutdown request for one or more SimpliVity Virtual Appliances

    This RESTAPI call only works if executed on the local SVA. So this cmdlet iterates through the specified
    hosts and connects to each specified host to sequentially shutdown the local SVA.

    Note, once executed, you'll need to reconnect back to a surviving SVA, using Connect-Svt to continue
    using the HPE SimpliVity cmdlets.
.PARAMETER HostName
    Specify the HostName running the SimpliVity Virtual Appliance to cancel the shutdown task on
.EXAMPLE
    PS C:\> Stop-SvtShutdown -HostName Host01
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtShutdown.md
#>
function Stop-SvtShutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$HostName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    try {
        $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
        # We get hosts here rather than using $SvtHost variable because we need state of SVA and cluster name
        # SVA state on target (and other) hosts is likely to be changing during shutdown activities.
        $AllHost = Get-SvtHost -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    
    $ThisHost = $Allhost | Where-Object HostName -eq $HostName
    $null = Connect-Svt -VirtualAppliance $ThisHost.ManagementIP -Credential $SvtConnection.Credential

    $Uri = $global:SvtConnection.VA + '/api/hosts/' + $ThisHost.HostId +
    '/cancel_virtual_controller_shutdown'

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
    }
    catch {
        Write-Warning "$($_.Exception.Message), failed to stop the shutdown process on host $ThisHostName"
    }

    $Response.cancellation_status | ForEach-Object {
        [PSCustomObject]@{
            VirtualController  = $ThisHost.ManagementIP
            CancellationStatus = $_.Status
        }
    }
}

#endregion Host

#region Cluster

<#
.SYNOPSIS
    Display HPE SimpliVity cluster information
.DESCRIPTION
    Shows cluster information from the SimpliVity Federation

    Free Space is shown in green if at least 20% of the allocated storage is free,
    yellow if free space is between 10% and 20% and red if less than 10% is free.
.PARAMETER ClusterName
    Show information about the specified cluster only
.EXAMPLE
    PS C:\> Get-SvtCluster

    Shows information about all clusters in the Federation
.EXAMPLE
    PS C:\> Get-SvtCluster Prod01
    PS C:\> Get-SvtCluster -Name Prod01

    Shows information about the specified cluster
.EXAMPLE
    PS C:\> Get-SvtCluster cluster1,cluster2

    Shows information about the specified clusters
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Cluster
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCluster.md
#>
function Get-SvtCluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters?show_optional_fields=true&case=insensitive' +
    "&sort=name&order=ascending"

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&name=$($ClusterName -join ',')"
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ClusterName') -and $Response.Count -notmatch $ClusterName.Count) {
        throw "At least 1 specified cluster names in '$ClusterName' not found"
    }

    $Response.omnistack_clusters | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.Cluster'
            DataCenterName           = $_.hypervisor_object_parent_name
            DataCenterId             = $_.hypervisor_object_parent_id
            Type                     = $_.type
            Version                  = $_.version
            HypervisorClusterId      = $_.hypervisor_object_id
            Members                  = $_.members
            ClusterName              = $_.name
            ArbiterIP                = $_.arbiter_address
            ArbiterConnected         = $_.arbiter_connected
            ArbiterRequired          = $_.arbiter_required
            ArbiterConfigured        = $_.arbiter_configured
            HypervisorType           = $_.hypervisor_type
            ClusterId                = $_.id
            HypervisorIP             = $_.hypervisor_management_system
            HypervisorName           = $_.hypervisor_management_system_name
            UsedLogicalCapacityGB    = '{0:n0}' -f ($_.used_logical_capacity / 1gb)
            UsedCapacityGB           = '{0:n0}' -f ($_.used_capacity / 1gb)
            CompressionRatio         = $_.compression_ratio
            StoredUnCompressedDataGB = '{0:n0}' -f ($_.stored_uncompressed_data / 1gb)
            StoredCompressedDataGB   = '{0:n0}' -f ($_.stored_compressed_data / 1gb)
            EfficiencyRatio          = $_.efficiency_ratio
            UpgradeTaskId            = $_.upgrade_task_id
            DeduplicationRatio       = $_.deduplication_ratio
            UpgradeState             = $_.upgrade_state
            LocalBackupCapacityGB    = '{0:n0}' -f ($_.local_backup_capacity / 1gb)
            ClusterGroupIds          = $_.cluster_group_ids
            TimeZone                 = $_.time_zone
            InfoSightRegistered      = $_.infosight_configuration.infosight_registered
            InfoSightEnabled         = $_.infosight_configuration.infosight_enabled
            InfoSightProxyURL        = $_.infosight_configuration.infosight_proxy_url
            ClusterFeatureLevel      = $_.cluster_feature_level
            IwoEnabled               = $_.iwo_enabled
            CapacitySavingsGB        = '{0:n0}' -f ($_.capacity_savings / 1gb)
            AllocatedCapacityGB      = '{0:n0}' -f ($_.allocated_capacity / 1gb)
            StoredVmDataGB           = '{0:n0}' -f ($_.stored_virtual_machine_data / 1gb)
            RemoteBackupCapacityGB   = '{0:n0}' -f ($_.remote_backup_capacity / 1gb)
            FreeSpaceGB              = '{0:n0}' -f ($_.free_space / 1gb)
        }
    }
}

<#
.SYNOPSIS
    Display information about HPE SimpliVity cluster throughput
.DESCRIPTION
    Calculates the throughput between each pair of omnistack_clusters in the federation
.PARAMETER ClusterName
    Specify a cluster name
.PARAMETER Hour
    Show throughput for the specified number of hours (starting from OffsetHour)
.PARAMETER OffsetHour
    Show throughput starting from the specified offset (hours from now, default is now)
.EXAMPLE
    PS C:\> Get-SvtThroughput

    Displays the throughput information for the first cluster in the Federation, (alphabetically,
    by name)
.EXAMPLE
    PS C:\> Get-SvtThroughput -Cluster Prod01

    Displays the throughput information for the specified cluster
.INPUTS
    None
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtThroughput.md
#>
function Get-SvtThroughput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$ClusterName = (Get-SvtCluster |
            Sort-Object ClusterName | Select-Object -ExpandProperty ClusterName -First 1),

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$Hour = 12,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.Int32]$OffsetHour = 0
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Range = $Hour * 3600
    $Offset = $OffsetHour * 3600

    try {
        $ClusterId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
        Select-Object -ExpandProperty ClusterId

        $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $ClusterId + '/throughput'
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Uri = $Uri + "?time_offset=$Offset&range=$Range"
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.cluster_throughput | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName                       = 'HPE.SimpliVity.Throughput'
            Date                             = ConvertFrom-SvtUtc -Date $_.date
            DestinationClusterHypervisorId   = $_.destination_omnistack_cluster_hypervisor_object_parent_id
            DestinationClusterHypervisorName = $_.destination_omnistack_cluster_hypervisor_object_parent_name
            DestinationClusterId             = $_.destination_omnistack_cluster_id
            DestinationClusterName           = $_.destination_omnistack_cluster_name
            SourceClusterHypervisorId        = $_.source_omnistack_cluster_hypervisor_object_parent_id
            SourceClusterHypervisorName      = $_.source_omnistack_cluster_hypervisor_object_parent_name
            SourceClusterId                  = $_.source_omnistack_cluster_id
            SourceClusterName                = $_.source_omnistack_cluster_name
            AvgThroughput                    = '{0:n0}' -f $_.average_throughput
            MinThroughput                    = '{0:n0}' -f $_.data.minimum_throughput
            MinDate                          = ConvertFrom-SvtUtc -Date $_.data.date_of_minimum
            MaxThroughput                    = '{0:n0}' -f $_.data.maximum_throughput
            MaxDate                          = ConvertFrom-SvtUtc -Date $_.data.date_of_maximum
        }
    }
}

<#
.SYNOPSIS
    Displays the timezones that HPE SimpliVity supports
.DESCRIPTION
    Displays the timezones that HPE SimpliVity supports
.EXAMPLE
    PS C:\> Get-SvtTimezone

.INPUTS
    None
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtTimezone.md
#>
function Get-SvtTimezone {
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/time_zone_list'

    try {
        Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Set properties of a HPE SimpliVity cluster
.DESCRIPTION
    Either sets the timezone or enables/disables the Intelligent Workload Optimizer (IWO)
    on a HPE SimpliVity cluster. Read the product documentation for more information about IWO.

    Use 'Get-SvtTimezone' to see a list of valid timezones
    Use 'Get-SvtCluster | Select-Object ClusterName,TimeZone' to see the currently set timezone
    Use 'Get-SvtCluster | Select-Object ClusterName, IwoEnabled' to see if IWO is currently enabled
.PARAMETER ClusterName
    Specify the cluster you want to change
.PARAMETER TimeZone
    Specify a valid timezone. Use Get-Timezone to see a list of valid timezones
.PARAMETER EnableIWO
    Specify either $true or $false to enable or disable IWO
.EXAMPLE
    PS C:\> Set-SvtCluster -Cluster PROD -Timezone 'Australia/Sydney'

    Sets the time zone for the specified cluster
.EXAMPLE
    PS C:\> Set-SvtCluster -EnableIWO:$true

    Enables IWO on the specified cluster. This command requires v4.1.0 or above.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtCluster.md
#>
function Set-SvtCluster {
    [CmdletBinding(DefaultParameterSetName = 'TimeZone')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'TimeZone')]
        [System.String]$TimeZone,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'EnableIWO')]
        [bool]$EnableIWO
    )

    try {
        $ClusterId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
        Select-Object -ExpandProperty ClusterId
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSCmdlet.ParameterSetName -eq 'TimeZone') {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $ClusterId + '/set_time_zone'

        if ($TimeZone -in (Get-SvtTimezone)) {
            $Body = @{ 'time_zone' = $TimeZone } | ConvertTo-Json
            Write-Verbose $Body
        }
        else {
            throw "Specified timezone $Timezone is not valid. Use Get-SvtTimezone to show valid timezones"
        }
    }
    else {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.16+json'
        }

        $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $ClusterId + '/set_iwo'
        if ($EnableIWO) {
            $Body = @{ 'enabled' = $true } | ConvertTo-Json
        }
        else {
            $Body = @{ 'enabled' = $false } | ConvertTo-Json
        }
        Write-Verbose $Body
    }

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Displays information about the connected HPE SimpliVity clusters in a Federation
.DESCRIPTION
    Displays information about other HPE SimpliVity clusters directly connected to the specified cluster
.PARAMETER ClusterName
    Specify a 'source' cluster name to display information about the SimpliVity clusters directly connected to it

    If no cluster is specified, the first cluster in the Federation is used (alphabetically)
.EXAMPLE
    PS C:\> Get-SvtClusterConnected -ClusterName Production

    Displays information about the clusters directly connected to the specified cluster
.EXAMPLE
    PS C:\> Get-SvtClusterConnected

    Displays information about the first cluster in the federation (by cluster name, alphabetically)
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtClusterConnected.md
#>
function Get-SvtClusterConnected {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $AllCluster = Get-SvtCluster -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if (-Not $PSBoundParameters.ContainsKey('ClusterName')) {
        $ClusterName = $AllCluster | Sort-Object ClusterName |
        Select-Object -First 1 -ExpandProperty ClusterName
        Write-Verbose "No cluster specified, using $ClusterName by default"
    }
    $ClusterId = $AllCluster | Where-Object ClusterName -eq $ClusterName |
    Select-Object -ExpandProperty ClusterId

    try {
        $Uri = $global:SvtConnection.VA + '/api/omnistack_clusters/' + $ClusterId + '/connected_clusters'
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.omnistack_clusters | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName             = 'HPE.SimpliVity.ConnectedCluster'
            ClusterId              = $_.id
            ClusterName            = $_.name
            ClusterType            = $_.type
            ClusterMembers         = $_.members
            ArbiterConnected       = $_.arbiter_connected
            ArbiterIP              = $_.arbiter_address
            HypervisorClusterId    = $_.hypervisor_object_id
            DataCenterId           = $_.hypervisor_object_parent_id
            DataCenterName         = $_.hypervisor_object_parent_name
            HyperVisorType         = $_.hypervisor_type
            HypervisorIP           = $_.hypervisor_management_system
            HypervisorName         = $_.hypervisor_management_system_name
            ClusterVersion         = $_.version
            ConnectedClusters      = $_.connected_clusters   # This property has been depreciated in 4.0.1
            InfosightConfiguration = $_.infosight_configuration
            ClusterGroupIDs        = $_.cluster_group_ids
            ClusterFeatureLevel    = $_.cluster_feature_level
        }
    }
}

#endregion Cluster

#region Policy

<#
.SYNOPSIS
    Display HPE SimpliVity backup policy rule information
.DESCRIPTION
    Shows the rules of backup policies from the SimpliVity Federation
.PARAMETER PolicyName
    Display information about the specified backup policy only
.PARAMETER RuleNumber
    If a backup policy has multiple rules, more than one object is displayed. Specify the rule number
    to display just that rule. This is useful when a rule needs to be edited or deleted.
.EXAMPLE
    PS C:\> Get-SvtPolicy

    Shows all policy rules for all backup policies
.EXAMPLE
    PS C:\> Get-SvtPolicy -PolicyName Silver, Gold

    Shows the rules from the specified backup policies
.EXAMPLE
    PS C:\> Get-SvtPolicy | Where RetentionDay -eq 7

    Show all policy rules that have a 7 day retention
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Policy
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtPolicy.md
#>
function Get-SvtPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$PolicyName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$RuleNumber
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SvtConnection.VA + '/api/policies?case=insensitive'
    if ($PSBoundParameters.ContainsKey('PolicyName')) {
        $PolicyList = $PolicyName -join ','
        $Uri += '&name=' + $PolicyList
    }
    else {
        if ($PSBoundParameters.ContainsKey('RuleNumber')) {
            throw 'You must specify a policy name to show the specified rule number'
        }
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('PolicyName') -and $Response.Count -notmatch $PolicyName.Count) {
        throw "At least one specified policy in '$PolicyList' not found"
    }

    $Response.policies | ForEach-Object {
        $Policy = $_.name
        $PolicyId = $_.id
        $PolicyClusterGroupIds = $_.cluster_group_ids
        if ($_.rules) {
            $_.rules | ForEach-Object {
                # Note: Cannot check for parameter $RuleNumber using 'if (-not $Rulenumber)'
                # This matches $RuleNumber=0, which is a valid value; '0' would return all rules.
                if (-not $PSBoundParameters.ContainsKey('RuleNumber') -or $RuleNumber -eq $_.number) {
                    [PSCustomObject]@{
                        PSTypeName        = 'HPE.SimpliVity.Policy'
                        PolicyName        = $Policy
                        PolicyId          = $PolicyId
                        ClusterGroupIds   = $PolicyClusterGroupIds
                        DestinationId     = $_.destination_id
                        EndTime           = $_.end_time
                        DestinationName   = $_.destination_name
                        ConsistencyType   = $_.consistency_type
                        FrequencyDay      = [math]::Round($_.frequency / 1440) #Frequency is in minutes
                        FrequencyHour     = [math]::Round($_.frequency / 60)
                        FrequencyMinute   = $_.frequency
                        AppConsistent     = $_.application_consistent
                        RuleNumber        = $_.number
                        StartTime         = $_.start_time
                        MaxBackup         = $_.max_backups
                        Day               = $_.days
                        RuleId            = $_.id
                        RetentionDay      = [math]::Round($_.retention / 1440) #Retention is in minutes
                        RetentionHour     = [math]::Round($_.retention / 60)
                        RetentionMinute   = $_.retention
                        ExternalStoreName = $_.external_store_name
                    }
                } # end if
            } # foreach rule
        }
        else {
            # Policy exists but it has no rules. This is often the case for the default policy
            [PSCustomObject]@{
                PSTypeName = 'HPE.SimpliVity.Policy'
                PolicyName = $Policy
                PolicyId   = $PolicyId
            }
        }
    } #end foreach policy
}

<#
.SYNOPSIS
    Create a new HPE SimpliVity backup policy
.DESCRIPTION
    Create a new, empty HPE SimpliVity backup policy. To create or replace rules for the new backup
    policy, use New-SvtPolicyRule.

    To assign the new backup policy, use Set-SvtDatastorePolicy to assign it to a datastore, or
    Set-SvtVmPolicy to assign it to a virtual machine.
.PARAMETER PolicyName
    The new backup policy name to create
.EXAMPLE
    PS C:\> New-SvtPolicy -Policy Silver

    Creates a new blank backup policy. To create or replace rules for the new backup policy,
    use New-SvtPolicyRule.
.EXAMPLE
    PS C:\> New-SvtPolicy Gold

    Creates a new blank backup policy. To create or replace rules for the new backup policy,
    use New-SvtPolicyRule.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicy.md
#>
function New-SvtPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    $Uri = $global:SvtConnection.VA + '/api/policies/'
    $Body = @{ 'name' = $PolicyName } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask # Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Create a new backup policy rule in a HPE SimpliVity backup policy
.DESCRIPTION
    Create backup policies within an existing HPE SimpliVity backup policy. Optionally, all the existing 
    policy rules can be replaced with the new policy rule. The destination for backups can be a SimpliVity 
    cluster or an appropriately configured external store (HPE StoreOnce Catalyst store). If no destination 
    is specified, the default is the local SimpliVity cluster (shown as "<Local>").

    You can also display an impact report rather than performing the change.
.PARAMETER PolicyName
    The backup policy to add/replace backup policy rules
.PARAMETER WeekDay
    Specifies the Weekday(s) to run backup, e.g. "Mon", "Mon,Tue" or "Mon,Wed,Fri"
.PARAMETER MonthDay
    Specifies the day(s) of the month to run backup, e.g. 1 or 1,11,21
.PARAMETER LastDay
    Specifies the last day of the month to run a backup
.PARAMETER All
    Specifies every day to run backup
.PARAMETER DestinationName
    Specifies the destination HPE SimpliVity cluster name or external store name. If not specified, the
    destination will be the local cluster. If an external store has the same name as a cluster, the cluster
    wins.
.PARAMETER StartTime
    Specifies the start time (24 hour clock) to run backup, e.g. 22:00
.PARAMETER EndTime
    Specifies the start time (24 hour clock) to run backup, e.g. 00:00
.PARAMETER FrequencyMin
    Specifies the frequency, in minutes (how many times a day to run).
    Must be between 1 and 1440 minutes (24 hours).
.PARAMETER RetentionDay
    Specifies the retention, in days.
.PARAMETER RetentionHour
    Specifies the retention, in hours. This parameter takes precedence if RetentionDay is also specified.
.PARAMETER ConsistencyType
    Available options are:
    1. NONE - This is the default and creates a crash consistent backup
    2. DEFAULT - Create application consistent backups using VMware Snapshot
    3. VSS - Create application consistent backups using Microsoft VSS in the guest operating system. Refer
       to the admin guide for requirements and supported applications

.PARAMETER ReplaceRules
    If this switch is specified, ALL existing rules in the specified backup policy are removed and replaced with this new rule.
.PARAMETER ImpactReportOnly
    Rather than create the policy rule, display a report showing the impact this change would make. The report
    shows projected daily backup rates and new total retained backups given the frequency and retention settings
    for the specified backup policy.
.EXAMPLE
    PS C:\> New-SvtPolicyRule -PolicyName Silver -All -DestinationName cluster1 -ReplaceRules

    Replaces all existing backup policy rules with a new rule, backup every day to the specified cluster,
    using the default start time (00:00), end time (00:00), Frequency (1440, or once per day), retention of
    1 day and no application consistency.
.EXAMPLE
    PS C:\> New-SvtPolicyRule -PolicyName Bronze -Last -ExternalStoreName StoreOnce-Data02 -RetentionDay 365

    Backup VMs on the last day of the month, storing them on the specified external datastore and retaining the
    backup for one year.

    PS C:\> New-SvtPolicyRule -PolicyName Silver -Weekday Mon,Wed,Fri -DestinationName cluster01 -RetentionDay 7

    Adds a new rule to the specified policy to run backups on the specified weekdays and retain backup for a week.
.EXAMPLE
    PS C:\> New-SvtPolicyRule ShortTerm -RetentionHour 4 -FrequencyMin 60 -StartTime 09:00 -EndTime 17:00

    Add a new rule to a policy called ShortTerm, to backup locally once per hour during office hours and retain the
    backup for 4 hours. (Note: -RetentionHour takes precedence over -RetentionDay if both are specified)
.EXAMPLE
    PS C:\> New-SvtPolicyRule Silver -LastDay -DestinationName Prod -RetentionDay 30 -ConsistencyType VSS

    Add a new rule to the specified policy to run an application consistent backup on the last day
    of each month, retaining it for 1 month.
.EXAMPLE
    PS C:\> New-SvtPolicyRule Silver -All -DestinationName Prod -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that creating this new policy rule would
    make to the system. The report shows projected daily backup rates and total retained backup rates.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicyRule.md
#>
function New-SvtPolicyRule {
    [CmdletBinding(DefaultParameterSetName = 'ByWeekDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByAllDay')]
        [switch]$All,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByWeekDay')]
        [array]$WeekDay,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByMonthDay')]
        [array]$MonthDay,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByLastDay')]
        [switch]$LastDay,

        [Parameter(Mandatory = $false)]
        [System.String]$DestinationName,

        [Parameter(Mandatory = $false)]
        [System.String]$StartTime = '00:00',

        [Parameter(Mandatory = $false)]
        [System.String]$EndTime = '00:00',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1440)]
        [System.String]$FrequencyMin = 1440, # Default is once per day

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetentionDay = 1,

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetentionHour,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NONE', 'DEFAULT', 'VSS')]  #'FAILEDVSS', 'NOT_APPLICABLE'
        [System.String]$ConsistencyType = 'NONE',

        [Parameter(Mandatory = $false)]
        [switch]$ReplaceRules,

        [Parameter(Mandatory = $false)]
        [Switch]$ImpactReportOnly
    )

    try {
        $PolicyId = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('DestinationName')) {
        try {
            $Destination = Get-SvtBackupDestination -Name $DestinationName -ErrorAction Stop

            if ($Destination.Type -eq 'Cluster') {
                $Body = @{ 'destination_id' = $Destination.Id }
            }
            else {
                $Body = @{ 'external_store_name' = $Destination.Id }
            }
        }
        catch {
            throw $_.Exception.Message
        }
    }
    else {
        # No destination specified, so the default destination is local cluster (<local>)
        $Body = @{ 'destination_id' = '' }
    }

    if ($PSBoundParameters.ContainsKey('WeekDay')) {
        foreach ($day in $WeekDay) {
            if ($day -notmatch '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$') {
                throw 'Invalid day entered, you must enter weekday in the form "Mon", "Mon,Fri" or "Mon,Thu,Sat"'
            }
        }
        $TargetDay = $WeekDay -join ','
    }
    elseif ($PSBoundParameters.ContainsKey('MonthDay')) {
        foreach ($day in $MonthDay) {
            if ($day -notmatch '^([1-9]|[12]\d|3[01])$') {
                throw 'Invalid day entered, you must enter month day(s) in the form "1", "1,15" or "1,12,24"'
            }
        }
        $TargetDay = $MonthDay -join ','
    }
    elseif ($PSBoundParameters.ContainsKey('LastDay')) {
        $TargetDay = 'last'
    }
    else {
        $TargetDay = 'all'
    }

    if ($StartTime -notmatch '^([01]\d|2[0-3]):?([0-5]\d)$') {
        throw 'Start time invalid. It must be in the form 00:00 (24 hour time). e.g. -StartTime 06:00'
    }
    if ($EndTime -notmatch '^([01]\d|2[0-3]):?([0-5]\d)$') {
        throw 'End time invalid. It must be in the form 00:00 (24 hour time). e.g. -EndTime 23:30'
    }

    if ($PSBoundParameters.ContainsKey('RetentionHour')) {
        $Retention = $RetentionHour * 60  #Retention is in minutes
    }
    else {
        $Retention = $RetentionDay * 1440 #Retention is in minutes
    }

    # The plugin doesn't expose application consistent tick box - application_consistent must be
    # true if consistency_type is VSS or DEFAULT. Otherwise the API sets it to NONE.
    $ConsistencyType = $ConsistencyType.ToUpper()
    if ($ConsistencyType -eq 'NONE') {
        $ApplicationConsistent = $false
    }
    else {
        $ApplicationConsistent = $true
    }

    $Body += @{
        'frequency'              = $FrequencyMin
        'retention'              = $Retention
        'days'                   = $TargetDay
        'start_time'             = $StartTime
        'end_time'               = $EndTime
        'application_consistent' = $ApplicationConsistent
        'consistency_type'       = $ConsistencyType
    }
    $Body = '[' + $($Body | ConvertTo-Json) + ']'
    Write-Verbose $Body

    if ($ImpactReportOnly) {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/impact_report/create_rules'
        if ($PSBoundParameters.ContainsKey('ReplaceRules')) {
            $Uri += "?replace_all_rules=$true"
        }
        else {
            $Uri += "?replace_all_rules=$false"
        }

        try {
            $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SvtImpactReport -Response $Response
    }
    else {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/rules'
        if ($PSBoundParameters.ContainsKey('ReplaceRules')) {
            $Uri += "?replace_all_rules=$true"
        }
        else {
            $Uri += "?replace_all_rules=$false"
        }

        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SvtTask = $Task
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Updates an existing HPE SimpliVity backup policy rule
.DESCRIPTION
    Updates an existing HPE SimpliVity backup policy rule. You must specify at least:

    - the name of policy to update
    - the existing policy rule number
    - the required day (via -All, -Weekday, -Monthday or -Lastday), even if you're not changing the day

    All other parameters are optional, if not set the new policy rule will inherit the current policy
    rule settings.

    Note: A backup destination cannot be changed in a rule. You must first delete the rule and then recreate
    it using Remove-SvtPolicyRule and New-SvtPolicyRule respectively, to update the backup destination.

    Rule numbers start from 0 and increment by 1. Use Get-SvtPolicy to identify the rule you want to update.

    You can also display an impact report rather than performing the change.
.PARAMETER PolicyName
    The name of the backup policy to update
.PARAMETER RuleNumber
    The number of the policy rule to update. Use Get-SvtPolicy to show policy information
.PARAMETER WeekDay
    Specify the Weekday(s) to run the backup, e.g. Mon, Mon,Tue or Mon,Wed,Fri
.PARAMETER MonthDay
    Specify the day(s) of the month to run the backup, e.g. 1, 1,16 or 2,4,6,8,10,12,14,16,18,20,22,24,26,28
.PARAMETER LastDay
    Specifies the last day of the month to run the backup
.PARAMETER All
    Specifies every day to run the backup
.PARAMETER StartTime
    Specifies the start time (24 hour clock) to run backup, e.g. 22:00
    If not set, the existing policy rule setting is used
.PARAMETER EndTime
    Specifies the start time (24 hour clock) to run backup, e.g. 00:00
    If not set, the existing policy rule setting is used
.PARAMETER FrequencyMin
    Specifies the frequency, in minutes (how many times a day to run).
    Must be between 1 and 1440 minutes (24 hours).
    If not set, the existing policy rule setting is used
.PARAMETER RetentionDay
    Specifies the backup retention, in days.
    If not set, the existing policy rule setting is used
.PARAMETER RetentionHour
    Specifies the backup retention, in hours. This parameter takes precedence if RetentionDay is also specified.
    If not set, the existing policy rule setting is used
.PARAMETER ConsistencyType
    Available options are:
    1. NONE - This is the default and creates a crash consistent backup
    2. DEFAULT - Create application consistent backups using VMware Snapshot
    3. VSS - Create application consistent backups using Microsoft VSS in the guest operating system. Refer
       to the admin guide for requirements and supported applications

    If not set, the existing policy rule setting is used
.PARAMETER ImpactReportOnly
    Rather than update the policy rule, display a report showing the impact this change would make. The report
    shows projected daily backup rates and new total retained backups given the frequency and retention settings
    for the specified backup policy.
.EXAMPLE
    PS C:\> Update-SvtPolicyRule -Policy Gold -RuleNumber 2 -Weekday Sun,Fri -StartTime 20:00 -EndTime 23:00

    Updates rule number 2 in the specified policy with a new weekday policy. start and finish times. This command
    inherits the existing retention, frequency, and application consistency settings from the existing rule.
.EXAMPLE
    PS C:\> Update-SvtPolicyRule -Policy Bronze -RuleNumber 1 -LastDay
    PS C:\> Update-SvtPolicyRule Bronze 1 -LastDay

    Both commands update rule 1 in the specified policy with a new day. All other settings are inherited from
    the existing backup policy rule.
.EXAMPLE
    PS C:\> Update-SvtPolicyRule Silver 3 -MonthDay 1,7,14,21 -RetentionDay 30

    Updates the existing rule 3 in the specified policy to perform backups four times a month on the specified
    days and retains the backup for 30 days.
.EXAMPLE
    PS C:\> Update-SvtPolicyRule Gold 1 -All -RetentionHour 1 -FrequencyMin 20 -StartTime 9:00 -EndTime 17:00

    Updates the existing rule 1 in the Gold policy to backup 3 times per hour every day during office hours and
    retain each backup for 1 hour. (Note: -RetentionHour takes precedence over -RetentionDay if both are
    specified).
.EXAMPLE
    PS C:\> Update-SvtPolicyRule Silver 2 -All -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that updating this policy rule would
    make to the system. The report shows projected daily backup rates and total retained backup rates.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    - Changing the destination is not supported.
    - Replacing all policy rules is not supported. Use New-SvtPolicyRule instead.
    - Changing ConsistencyType to anything other than None or Default doesn't appear to work.
    - Changing ConsistencyType to anything other than None or Default doesn't appear to work.
    - Changing ConsistencyType to anything other than None or Default doesn't appear to work.
    - Use Remove-SvtPolicyRule and New-SvtPolicyRule to update ConsistencyType to VSS.
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Update-SvtPolicyRule.md
#>
function Update-SvtPolicyRule {
    [CmdletBinding(DefaultParameterSetName = 'ByWeekDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$RuleNumber,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByAllDay')]
        [switch]$All,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByWeekDay')]
        [array]$WeekDay,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByMonthDay')]
        [array]$MonthDay,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByLastDay')]
        [switch]$LastDay,

        [Parameter(Mandatory = $false)]
        [System.String]$StartTime,

        [Parameter(Mandatory = $false)]
        [System.String]$EndTime,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1440)]
        [System.String]$FrequencyMin,

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetentionDay,

        [Parameter(Mandatory = $false)]
        [System.Int32]$RetentionHour,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NONE', 'DEFAULT', 'VSS', 'FAILEDVSS', 'NOT_APPLICABLE')]
        [System.String]$ConsistencyType,

        [Parameter(Mandatory = $false)]
        [Switch]$ImpactReportOnly
    )

    try {
        $Policy = Get-SvtPolicy -PolicyName $PolicyName -RuleNumber $RuleNumber -ErrorAction Stop
        $PolicyId = $Policy | Select-Object -ExpandProperty PolicyId
        $RuleId = $Policy | Select-Object -ExpandProperty RuleId
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('WeekDay')) {
        foreach ($day in $WeekDay) {
            if ($day -notmatch '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$') {
                throw 'Invalid day entered, you must enter weekday in the form "Mon", "Mon,Fri" or "Mon,Thu,Sat"'
            }
        }
        $TargetDay = $WeekDay -join ','
    }
    elseif ($PSBoundParameters.ContainsKey('MonthDay')) {
        foreach ($day in $MonthDay) {
            if ($day -notmatch '^([1-9]|[12]\d|3[01])$') {
                throw 'Invalid day entered, you must enter month day(s) in the form "1", "1,15" or "1,12,24"'
            }
        }
        $TargetDay = $MonthDay -join ','
    }
    elseif ($PSBoundParameters.ContainsKey('LastDay')) {
        $TargetDay = 'last'
    }
    else {
        $TargetDay = 'all'
    }

    if ($PSBoundParameters.ContainsKey('StartTime')) {
        if ($StartTime -notmatch '^([01]\d|2[0-3]):?([0-5]\d)$') {
            throw 'Start time invalid. It must be in the form 00:00 (24 hour time). e.g. -StartTime 06:00'
        }
    }
    else {
        $StartTime = $Policy | Select-Object -ExpandProperty StartTime
        Write-Verbose "Inheriting existing start time $StartTime"
    }

    if ($PSBoundParameters.ContainsKey('EndTime')) {
        if ($EndTime -notmatch '^([01]\d|2[0-3]):?([0-5]\d)$') {
            throw 'End time invalid. It must be in the form 00:00 (24 hour time). e.g. -EndTime 23:30'
        }
    }
    else {
        $EndTime = $Policy | Select-Object -ExpandProperty EndTime
        Write-Verbose "Inheriting existing end time $EndTime"
    }

    if ( -not $PSBoundParameters.ContainsKey('FrequencyMin')) {
        $FrequencyMin = ($Policy | Select-Object -ExpandProperty FrequencyHour) * 60
        Write-Verbose "Inheriting existing backup frequency of $FrequencyMin minutes"
    }

    if ($PSBoundParameters.ContainsKey('RetentionHour')) {
        $Retention = $RetentionHour * 60  #Retention is in minutes
    }
    elseif ($PSBoundParameters.ContainsKey('RetentionDay')) {
        $Retention = $RetentionDay * 1440 #Retention is in minutes
    }
    else {
        $Retention = ($Policy | Select-Object -ExpandProperty RetentionMinute)
        Write-Verbose "Inheriting existing retention of $Retention minutes"
    }

    if ( -not $PSBoundParameters.ContainsKey('ConsistencyType')) {
        $ConsistencyType = ($Policy | Select-Object -ExpandProperty ConsistencyType).ToUpper()
        Write-Verbose "Inheriting existing consistency type $ConsistencyType"
    }

    # The new HTML5 client doesn't expose application consistent tick box - application_consistent must be
    # true if consistency_type is VSS or DEFAULT. Otherwise the API sets it to NONE.
    $ConsistencyType = $ConsistencyType.ToUpper()
    if ($ConsistencyType -eq 'NONE') {
        $ApplicationConsistent = $false
    }
    else {
        $ApplicationConsistent = $true
    }

    $Body = @{
        'frequency'              = $FrequencyMin
        'retention'              = $Retention
        'days'                   = $TargetDay
        'start_time'             = $StartTime
        'end_time'               = $EndTime
        'application_consistent' = $ApplicationConsistent
        'consistency_type'       = $ConsistencyType
    }

    if ($ImpactReportOnly) {
        $Body += @{ 'rule_id' = $RuleId }
        $Body = '[' + $($Body | ConvertTo-Json) + ']'
        Write-Verbose $Body

        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId +
        '/impact_report/edit_rules?replace_all_rules=false'

        try {
            $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SvtImpactReport -Response $Response
    }
    else {
        $Body = $Body | ConvertTo-Json
        Write-Verbose $Body

        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/rules/' + $RuleId

        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Put -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SvtTask = $Task
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Deletes a backup rule from an existing HPE SimpliVity backup policy
.DESCRIPTION
    Delete an existing rule from a HPE SimpliVity backup policy. You must specify the policy name and
    the rule number to be removed.

    Rule numbers start from 0 and increment by 1. Use Get-SvtPolicy to identify the rule you want to delete.

    You can also display an impact report rather than performing the change.
.PARAMETER PolicyName
    Specify the policy containing the policy rule to delete
.PARAMETER RuleNumber
    Specify the number assigned to the policy rule to delete. Use Get-SvtPolicy to show policy information
.PARAMETER ImpactReportOnly
    Rather than remove the policy rule, display a report showing the impact this change would make. The report
    shows projected daily backup rates and new total retained backups given the frequency and retention settings
    for the specified backup policy.
.EXAMPLE
    PS C:\> Remove-SvtPolicyRule -Policy Gold -RuleNumber 2

    Removes rule number 2 in the specified backup policy
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtPolicyRule.md
#>
function Remove-SvtPolicyRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$RuleNumber,

        [Parameter(Mandatory = $false)]
        [Switch]$ImpactReportOnly
    )

    try {
        $Policy = Get-SvtPolicy -PolicyName $PolicyName -RuleNumber $RuleNumber -ErrorAction Stop

        $PolicyId = $Policy | Select-Object -ExpandProperty PolicyId -Unique
        $RuleId = $Policy | Select-Object -ExpandProperty RuleId -Unique
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($PolicyId)) {
        $Message = 'Specified policy name or Rule number not found. Use Get-SvtPolicy to determine ' +
        'rule number for the rule you want to delete'
        throw $Message
    }

    if ($ImpactReportOnly) {
        # Delete rule impact performed, show report
        try {
            $Header = @{
                'Authorization' = "Bearer $($global:SvtConnection.Token)"
                'Accept'        = 'application/json'
                'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
            }
            $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/rules/' +
            $RuleId + '/impact_report/delete_rule'
            $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SvtImpactReport -Response $Response
    }
    else {
        # Delete the backup policy rule
        try {
            $Header = @{
                'Authorization' = "Bearer $($global:SvtConnection.Token)"
                'Accept'        = 'application/json'
            }
            $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/rules/' + $RuleId
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SvtTask = $Task
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Rename a HPE SimpliVity backup policy
.DESCRIPTION
    Rename a HPE SimpliVity backup policy
.PARAMETER PolicyName
    The existing backup policy name
.PARAMETER NewPolicyName
    The new name for the backup policy
.EXAMPLE
    PS C:\> Get-SvtPolicy
    PS C:\> Rename-SvtPolicy -PolicyName Silver -NewPolicyName Gold

    The first command confirms the new policy name doesn't exist.
    The second command renames the backup policy as specified.
.EXAMPLE
    PS C:\> Rename-SvtPolicy Silver Gold

    Renames the backup policy as specified
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Rename-SvtPolicy.md
#>
function Rename-SvtPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$NewPolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $PolicyId = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
        Select-Object -ExpandProperty PolicyId -Unique

        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/rename'

        $Body = @{ 'name' = $NewPolicyName } | ConvertTo-Json
        Write-Verbose $Body
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Removes a HPE SimpliVity backup policy
.DESCRIPTION
    Removes a HPE SimpliVity backup policy, providing it is not in use be any datastores or virtual machines.
.PARAMETER PolicyName
    The policy to delete
.EXAMPLE
    PS C:\> Get-SvtVm | Select VmName, PolicyName
    PS C:\> Get-SvtDatastore | Select DatastoreName, PolicyName
    PS C:\> Remove-SvtPolicy -PolicyName Silver

    Confirm there are no datastores or VMs using the backup policy and then delete it.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtPolicy.md
#>
function Remove-SvtPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $PolicyId = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    # Confirm the policy is not in use before deleting it. To do this, check both datastores and VMs
    $UriList = @(
        $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/virtual_machines'
        $global:SvtConnection.VA + '/api/policies/' + $PolicyId + '/datastores'
    )
    [Bool]$ObjectFound = $false
    [String]$Message = ''
    Foreach ($Uri in $UriList) {
        try {
            $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        if ($Task.datastores) {
            $Message += "There are $(($Task.datastores).Count) databases using backup policy $PolicyName. "
            $ObjectFound = $true
        }
        if ($Task.virtual_machines) {
            $Message += "There are $(($Task.virtual_machines).Count) virtual machines using backup " +
            "policy $PolicyName. "
            $ObjectFound = $true
        }
    }
    if ($ObjectFound) {
        throw "$($Message)Cannot remove a backup policy that is still in use"
    }

    try {
        $Uri = $global:SvtConnection.VA + '/api/policies/' + $PolicyId
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Suspends the HPE SimpliVity backup policy for a host, a cluster or the federation
.DESCRIPTION
    Suspend the HPE SimpliVity backup policy for a host, a cluster or the federation
.PARAMETER ClusterName
    Apply to specified Cluster name
.PARAMETER HostName
    Apply to specified host name
.PARAMETER Federation
    Apply to federation
.EXAMPLE
    PS C:\> Suspend-SvtPolicy -Federation

    Suspends backup policies for the entire federation

    NOTE: This command will only work when connected to a SimpliVity Virtual Appliance, (not when connected
    to a Managed Virtual Appliance)
.EXAMPLE
    PS C:\> Suspend-SvtPolicy -ClusterName Prod

    Suspend backup policies for the specified cluster
.EXAMPLE
    PS C:\> Suspend-SvtPolicy -HostName host01

    Suspend backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Suspend-SvtPolicy.md
#>
function Suspend-SvtPolicy {
    [CmdletBinding(DefaultParameterSetName = 'ByHost')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHost')]
        [System.String]$HostName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCluster')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByFederation')]
        [switch]$Federation
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    $Uri = $global:SvtConnection.VA + '/api/policies/suspend'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        try {
            $TargetId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
            Select-Object -ExpandProperty ClusterId

            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    elseif ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            $TargetId = $global:SvtHost | Where-Object HostName -eq $HostName |
            Select-Object -ExpandProperty HostId

            $TargetType = 'host'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    else {
        $TargetId = ''
        $TargetType = 'federation'
    }

    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Resumes the HPE SimpliVity backup policy for a host, a cluster or the federation
.DESCRIPTION
    Resumes the HPE SimpliVity backup policy for a host, a cluster or the federation
.PARAMETER ClusterName
    Apply to specified cluster name
.PARAMETER HostName
    Apply to specified host name
.PARAMETER Federation
    Apply to federation
.EXAMPLE
    PS C:\> Resume-SvtPolicy -Federation

    Resumes backup policies for the federation

    NOTE: This command will only work when connected to an SimpliVity Virtual Appliance, (not when connected
    to a Managed Virtual Appliance)
.EXAMPLE
    PS C:\> Resume-SvtPolicy -ClusterName Prod

    Resumes backup policies for the specified cluster
.EXAMPLE
    PS C:\> Resume-SvtPolicy -HostName host01

    Resumes backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Resume-SvtPolicy.md
#>
function Resume-SvtPolicy {
    [CmdletBinding(DefaultParameterSetName = 'ByHost')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHost')]
        [System.String]$HostName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCluster')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByFederation')]
        [switch]$Federation
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    $Uri = $global:SvtConnection.VA + '/api/policies/resume'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        try {
            $TargetId = Get-SvtCluster -ClusterName $ClusterName -ErrorAction Stop |
            Select-Object -ExpandProperty ClusterId

            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    elseif ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            $TargetId = $global:SvtHost | Where-Object HostName -eq $HostName |
            Select-Object -ExpandProperty HostId

            $TargetType = 'host'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    else {
        $TargetId = ''
        $TargetType = 'federation'
    }

    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Display a report showing information about HPE SimpliVity backup rates and limits
.DESCRIPTION
    Display a report showing information about HPE SimpliVity backup rates and limits
.EXAMPLE
    PS C:\> Get-SvtPolicyScheduleReport

.INPUTS
    None
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtPolicyScheduleReport.md
#>
function Get-SvtPolicyScheduleReport {
    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SvtConnection.VA + '/api/policies/policy_schedule_report'

    try {
        $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response | ForEach-Object {
        [PSCustomObject]@{
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
    Display information about VMs running on HPE SimpliVity storage
.DESCRIPTION
    Display information about virtual machines running in the HPE SimpliVity Federation. Accepts
    parameters to limit the objects returned.

    Verbose is automatically turned on to show more information about what this command is doing.
.PARAMETER VmName
    Display information for the specified virtual machine
.PARAMETER VmId
    Display information for the specified virtual machine ID
.PARAMETER DatastoreName
    Display information for virtual machines on the specified datastore
.PARAMETER ClusterName
    Display information for virtual machines on the specified cluster
.PARAMETER PolicyName
    Display information for virtual machines that have the specified backup policy assigned
.PARAMETER HostName
    Display information for virtual machines on the specified host
.PARAMETER State
    Display information for virtual machines with the specified state
.PARAMETER Limit
    The maximum number of virtual machines to display
.EXAMPLE
    PS C:\> Get-SvtVm

    Shows all virtual machines in the Federation with state "ALIVE", which is the default state
.EXAMPLE
    PS C:\> Get-SvtVm -VmName Win2019-01
    PS C:\> Get-SvtVm -Name Win2019-01
    PS C:\> Get-SvtVm Win2019-01

    All three commands perform the same action - show information about the specified virtual machine(s) with
    state "ALIVE", which is the default state

    The first command uses the parameter name; the second uses an alias for VmName; the third uses positional
    parameter, which accepts a VM name.
.EXAMPLE
    PS C:\> Get-SvtVm -State DELETED
    PS C:\> Get-SvtVm -State ALIVE,REMOVED,DELETED

    Shows all virtual machines in the Federation with the specified state(s)
.EXAMPLE
    PS C:\> Get-SvtVm -DatastoreName DS01,DS02

    Shows all virtual machines residing on the specified datastore(s)
.EXAMPLE
    PS C:\> Get-SvtVm VM1,VM2,VM3 | Out-GridView -Passthru | Export-CSV FilteredVmList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports
    this to a CSV
.EXAMPLE
    PS C:\> Get-SvtVm -HostName esx04 | Select-Object Name, SizeGB, Policy, HAstatus

    Show the VMs from the specified host. Show the selected properties only.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.VirtualMachine
.NOTES
    Author: Roy Atkins, HPE Pointnext Services

    Known issues:
    OMNI-69918 - GET calls for virtual machine objects may result in OutOfMemortError when exceeding 8000 objects
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVm.md
#>
function Get-SvtVm {
    [CmdletBinding(DefaultParameterSetName = 'ByVmName')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVmName')]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [Alias('Id')]
        [System.String[]]$VmId,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [System.String[]]$DatastoreName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [System.String[]]$ClusterName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByPolicyName')]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByHostName')]
        [System.String]$HostName, # Note: API only accepts one host id

        [Parameter(Mandatory = $false)]
        [ValidateSet('ALIVE', 'DELETED', 'REMOVED')]
        [System.String[]]$State = 'ALIVE',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 5000)]   # Limited to avoid out of memory errors (OMNI-69918) (Runtime error over 5000)
        [System.Int32]$Limit = 500
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = "$($global:SvtConnection.VA)/api/virtual_machines" +
    '?show_optional_fields=true' +
    '&case=insensitive' +
    '&sort=name' +
    '&order=ascending' +
    "&limit=$Limit" +
    "&state=$($State -join ',')"

    if ($PSBoundParameters.ContainsKey('VmName')) {
        $Uri += "&name=$($VmName -join ',')"
    }

    if ($PSBoundParameters.ContainsKey('VmId')) {
        $Uri += "&id=$($VmId -join ',')"
    }

    if ($PSBoundParameters.ContainsKey('PolicyName')) {
        $Uri += "&policy_name=$($PolicyName -join ',')"
    }

    if ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $HostName = Resolve-SvtFullHostName -HostName $HostName -ErrorAction Stop
            $HostId = $global:SvtHost | Where-Object HostName -eq $HostName | Select-Object -ExpandProperty HostId
            $Uri += "&host_id=$HostId"
        }
        catch {
            throw $_.Exception.Message
        }
    }

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&omnistack_cluster_name=$($ClusterName -join ',')"
    }

    if ($PSBoundParameters.ContainsKey('DatastoreName')) {
        $Uri += "&datastore_name=$($DatastoreName -join ',')"
    }

    try {
        $Response = Invoke-SvtRestMethod -Uri "$Uri" -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $VmCount = $Response.count
    if ($VmCount -gt $Limit) {
        $Message = "There are $VmCount matching virtual machines, but limited to displaying only $Limit. " +
        'Either increase -Limit or use more restrictive parameters'
        Write-Warning $Message
    }
    else {
        Write-Verbose "There are $VmCount matching virtual machines"
    }

    if ($PSBoundParameters.ContainsKey('VmName') -and $Response.Count -notmatch $VmName.Count) {
        throw "At least 1 specified virtual machine name in '$VmName' not found"
    }

    if ($PSBoundParameters.ContainsKey('VmId') -and $Response.Count -notmatch $VmId.Count) {
        throw "At least 1 specified virtual machine ID in '$VmId' not found"
    }

    $Response.virtual_machines | ForEach-Object {

        $ThisHost = $global:SvtHost | Where-Object HostID -eq $_.host_id | Select-Object -ExpandProperty HostName
        if ($null -eq $ThisHost -and $_.state -eq 'ALIVE') {
            $ThisHost = '*ComputeNode'
        }

        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.VirtualMachine'
            PolicyId                 = $_.policy_id
            CreateDate               = ConvertFrom-SvtUtc -Date $_.created_at
            PolicyName               = $_.policy_name
            DatastoreName            = $_.datastore_name
            ClusterName              = $_.omnistack_cluster_name
            DeletedDate              = ConvertFrom-SvtUtc -Date $_.deleted_at
            AppAwareVmStatus         = $_.app_aware_vm_status
            HostName                 = $ThisHost
            HostId                   = $_.host_id
            HypervisorId             = $_.hypervisor_object_id
            VmName                   = $_.name
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
            HAstatus                 = $_.ha_status
            HAresyncProgress         = $_.ha_resynchronization_progress
            VmPowerState             = $_.hypervisor_virtual_machine_power_state
        }
    } # foreach VM
}

<#
.SYNOPSIS
    Display the primary and secondary replica locations for HPE SimpliVity virtual machines
.DESCRIPTION
    Display the primary and secondary replica locations for HPE SimpliVity virtual machines
.PARAMETER VmName
    Display information for the specified virtual machine
.PARAMETER DatastoreName
    Display information for virtual machines on the specified datastore
.PARAMETER ClusterName
    Display information for virtual machines on the specified cluster
.PARAMETER HostName
    Display information for virtual machines on the specified host
.EXAMPLE
    PS C:\> Get-SvtVmReplicaSet

    Displays the primary and secondary locations for all virtual machine replica sets.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVmReplicaSet.md
#>
function Get-SvtVmReplicaSet {
    [CmdletBinding(DefaultParameterSetName = 'ByVm')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVm')]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByDatastore')]
        [System.String[]]$DatastoreName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCluster')]
        [System.String[]]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByHost')]
        [System.String]$HostName
    )

    begin {
        if ($PSBoundParameters.ContainsKey('VmName')) {
            $VmObj = Get-SvtVm -VmName $VmName
        }
        elseif ($PSBoundParameters.ContainsKey('DatastoreName')) {
            $VmObj = Get-SvtVm -DatastoreName $DatastoreName
        }
        elseif ($PSBoundParameters.ContainsKey('ClusterName')) {
            $VmObj = Get-SvtVm -ClusterName $ClusterName
        }
        elseif ($PSBoundParameters.ContainsKey('HostName')) {
            $VmObj = Get-SvtVm -HostName $HostName
        }
        else {
            $VmObj = Get-SvtVm  # default is all VMs
        }
    }

    process {
        foreach ($VM in $VmObj) {
            $PrimaryId = $VM.ReplicaSet | Where-Object role -eq 'PRIMARY' |
            Select-Object -ExpandProperty id

            $SecondaryId = $VM.ReplicaSet | Where-Object role -eq 'SECONDARY' |
            Select-Object -ExpandProperty id

            $PrimaryHost = $global:SvtHost | Where-Object HostId -eq $PrimaryId |
            Select-Object -ExpandProperty HostName

            $SecondaryHost = $global:SvtHost | Where-Object HostId -eq $SecondaryId |
            Select-Object -ExpandProperty HostName

            [PSCustomObject]@{
                PSTypeName  = 'HPE.SimpliVity.ReplicaSet'
                VmName      = $VM.VmName
                State       = $VM.State
                HAstatus    = $VM.HAstatus
                ClusterName = $VM.ClusterName
                Primary     = $PrimaryHost
                Secondary   = $SecondaryHost
            }
        }
    }
}

<#
.SYNOPSIS
    Clone a Virtual Machine hosted on SimpliVity storage
.DESCRIPTION
    This cmdlet will clone the specified virtual machine, using the new name provided.
.PARAMETER VmName
    Specify the VM to clone
.PARAMETER CloneName
    Specify the name of the new clone
.PARAMETER ConsistencyType
    Available options are:
    1. NONE - This is the default and creates a crash consistent backup
    2. DEFAULT - Create application consistent backups using VMware Snapshot
    3. VSS - Create application consistent backups using Microsoft VSS in the guest operating system. Refer
       to the admin guide for requirements and supported applications
.EXAMPLE
    PS C:\> New-SvtClone -VmName MyVm1

    Create a clone with the default name 'MyVm1-clone-200212102304', where the suffix is a date stamp in
    the form 'yyMMddhhmmss'
.EXAMPLE
    PS C:\> New-SvtClone -VmName Win2019-01 -CloneName Win2019-Clone
    PS C:\> New-SvtClone -VmName Win2019-01 -CloneName Win2019-Clone -ConsistencyType NONE

    Both commands do the same thing, they create an application consistent clone of the specified
    virtual machine, using a snapshot
.EXAMPLE
    PS C:\> New-SvtClone -VmName Linux-01 -CloneName Linux-01-New -ConsistencyType DEFAULT

    Create a crash-consistent clone of the specified virtual machine
.EXAMPLE
    PS C:\> New-SvtClone -VmName Win2019-06 -CloneName Win2019-Clone -ConsistencyType VSS

    Creates an application consistent clone of the specified Windows VM, using a VSS snapshot. The clone
    will fail for None-Windows virtual machines.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtClone.md
#>
function New-SvtClone {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$VmName,

        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('Name')]
        [System.String]$CloneName = "$VmName-clone-$(Get-Date -Format 'yyMMddhhmmss')",

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('DEFAULT', 'VSS', 'NONE')]
        [System.String]$ConsistencyType = 'NONE'
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SvtConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $VmId = Get-SvtVm -VmName $VmName -ErrorAction Stop | Select-Object -ExpandProperty VmId
        $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmId + '/clone'
        Write-Verbose "Creating a clone of $VmName called $CloneName"
    }
    catch {
        throw $_.Exception.Message
    }

    if ($ConsistencyType -eq 'VSS') {
        Write-Verbose 'Consistency type of VSS will only work with Windows virtual machines'
    }

    if ($ConsistencyType -eq 'NONE') {
        $ApplicationConsistent = $false
    }
    else {
        $ApplicationConsistent = $true
    }

    $Body = @{
        'virtual_machine_name' = $CloneName
        'app_consistent'       = $ApplicationConsistent
        'consistency_type'     = $ConsistencyType.ToUpper()
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    # Useful to keep the task objects in this session, so we can keep track of them with Get-SvtTask
    $global:SvtTask = $Task
    $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Move one or more existing virtual machines from one HPE SimpliVity datastore to another
.DESCRIPTION
    Relocates the specified virtual machines to a different datastore in the federation. The datastore can be
    in the same or a different datacenter. Consider the following when moving a virtual machine:
    1. You must power off the OS guest before moving, otherwise the operation fails
    2. In its new location, make sure the moved VM boots up after the local SVA and shuts down before it
    3. Any pre-move backups (local or remote) stay associated with a VM after it moves. You can use these backups
    to restore the moved VM(s)
    4. HPE OmniStack only supports one move operation per VM at a time. You must wait for the task to complete before
    attempting to move the same VM again
    5. If moving VM(s) out of the current cluster, DRS rules (created by the Intelligent Workload Optimizer) will
    vMotion the moved VM(s) to the destination
.PARAMETER VmName
    The name(s) of the virtual machines you'd like to move
.PARAMETER DatastoreName
    The destination datastore
.EXAMPLE
    PS C:\> Move-SvtVm -VmName MyVm -Datastore DR-DS01

    Moves the specified VM to the specified datastore
.EXAMPLE
    PS C:\> "VM1", "VM2" | Move-SvtVm -Datastore DS03

    Moves the two VMs to the specified datastore
.EXAMPLE
    PS C:\> Get-VM | Where-Object VmName -match "WEB" | Move-SvtVm -Datastore DS03
    PS C:\> Get-SvtTask

    Move VM(s) with "Web" in their name to the specified datastore. Use Get-SvtTask to monitor the progress
    of the move task(s)
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Move-SvtVm.md
#>
function Move-SvtVm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [System.String]$VmName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$DatastoreName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        try {
            $DatastoreId = Get-SvtDatastore -DatastoreName $DatastoreName -ErrorAction Stop |
            Select-Object -ExpandProperty DatastoreId
        }
        catch {
            throw $_.Exception.Message
        }
    }
    process {
        foreach ($VM in $VmName) {
            try {
                $VmObj = Get-SvtVm -VmName $VM -ErrorAction Stop
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmObj.VmId + '/move'

                $Body = @{
                    'virtual_machine_name'     = $VmObj.VmName
                    'destination_datastore_id' = $DatastoreId
                } | ConvertTo-Json
                Write-Verbose $Body
            }
            catch {
                throw $_.Exception.Message
            }

            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), move failed for VM $VM"
            }
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SvtTask
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Sets a backup policy or the user credentials to enable application consistent backups on HPE SimpliVity
    virtual machines.
.DESCRIPTION
    Either sets a new HPE SimpliVity backup policy on virtual machines or sets the guest user credentials
    to enable application consistent backups. Optionally, for backup policy changes, display an impact report
    rather than performing the action.

    When a VM is first created, it inherits the backup policy set on the HPE SimpliVity datastore it is
    created on. Use this command to explicitly set a different backup policy for specified virtual machine(s).
    Once set (either automatically or manually), a VM will retain the same backup policy, even if it is moved
    to another datastore with a different default backup policy.

    To create application-consistent backups that use Microsoft Volume Shadow Copy Service (VSS), enter the
    guest credentials for one or more virtual machines. The guest credentials must use administrator
    privileges for VSS. The target virtual machine(s) must be powered on. The target virtual machine(s) must
    be running Microsoft Windows.

    The user name can be specified in the following forms:
       "administrator", a local user account
       "domain\svc_backup", an Active Directory domain user account
       "svc_backup@domain.com", Active Directory domain user account

    The password cannot be entered as a parameter. The command will prompt for a secure string to be entered.

.PARAMETER PolicyName
    The name of the new policy to use when setting the backup policy on one or more VMs
.PARAMETER VmName
    The target virtual machine(s)
.PARAMETER VmId
    Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from
    the pipeline, using Get-SvtVm. This is more efficient (single call to the SimpliVity API).
.PARAMETER ImpactReportOnly
    Rather than change the backup policy on one or more virtual machines, display a report showing the impact
    this action would make. The report shows projected daily backup rates and new total retained backups given
    the frequency and retention settings for the given backup policy.
.PARAMETER Username
    When setting the user credentials, specify the username
.PARAMETER Password
    When setting the user credentials, the password must be entered as a secure string (not as a parameter)
.EXAMPLE
    PS C:\> Get-SvtVm -Datastore DS01 | Set-SvtVmPolicy Silver

    Changes the backup policy for all VMs on the specified datastore to the backup policy named 'Silver'
.EXAMPLE
    Set-SvtVmPolicy Silver VM01

    Using positional parameters to apply a new backup policy to the VM
.EXAMPLE
    Get-SvtVm -Policy Silver | Set-SvtVmPolicy -PolicyName Gold -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that changing all virtual machines with
    the Silver backup policy to the Gold backup policy would make to the system. The report shows projected
    daily backup rates and total retained backup rates.
.EXAMPLE
    PS C:\> Set-SvtVm -VmName MyVm -Username svc_backup

    Prompts for the password of the specified account and sets the VSS credentials for the virtual machine.
.EXAMPLE
    PS C:\> "VM1", "VM2" | Set-SvtVm -Username twodogs\backupadmin

    Prompts for the password of the specified account and sets the VSS credentials for the two virtual machines.
    The command contacts the running Windows guest to confirm the validity of the password before setting it.
.EXAMPLE
    PS C:\> Get-VM Win2019-01 | Set-SvtVm -Username administrator
    PS C:\> Get-VM Win2019-01 | Select-Object VmName, AppAwareVmStatus

    Set the credentials for the specified virtual machine and then confirm they are set properly.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
    System.Management.Automation.PSCustomObject
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtVm.md
#>
function Set-SvtVm {
    [CmdletBinding(DefaultParameterSetName = 'SetPolicy')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SetPolicy')]
        [Alias('Policy')]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'SetPolicy')]
        [switch]$ImpactReportOnly,

        [Parameter(Mandatory = $false, ParameterSetName = 'SetPolicy',
            ValueFromPipelineByPropertyName = $true)]
        [System.String]$VmId,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SetCredential')]
        [System.String]$Username,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'SetCredential')]
        [System.Security.SecureString]$Password
    )

    begin {
        # This header is used by /backup_parameters (set credentials) and /policy_impact_report/apply_policy.
        # Not by /set_policy. This is fixed later
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }

        if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
            $VmList = @()
            try {
                $PolicyId = Get-SvtPolicy -PolicyName $PolicyName -ErrorAction Stop |
                Select-Object -ExpandProperty PolicyId -Unique
            }
            catch {
                throw $_.Exception.Message
            }

            if ($ImpactReportOnly) {
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/policy_impact_report/apply_policy'
            }
            else {
                # Fix header for /set_policy API call
                $Header.'Content-Type' = 'application/vnd.simplivity.v1.5+json'
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/set_policy'
            }
        }
        else {
            # Setting a user credential for VSS
            $SecurePass = (New-Object System.Management.AUtomation.PSCredential('user', $password)).`
                GetNetworkCredential().password

            $Body = @{
                'guest_username'            = $Username
                'guest_password'            = $SecurePass
                'override_guest_validation' = $false
                'app_aware_type'            = 'VSS'
            }
            $SecureBody = $Body
            $Body = $Body | ConvertTo-Json

            $SecureBody.guest_password = '*' * 10
            $SecureBody = $SecureBody | ConvertTo-Json
            Write-Verbose $SecureBody
        }
    }
    process {
        # VM objects passed in from Get-SvtVm
        if ($VmId) {
            if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
                # Both forms of the policy command (set report) uses a hash containing VM Ids (passed in)
                $VmList += $VmId
            }
            else {
                # Run a task to set user credentials on each VM (passed in)
                $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmId + '/backup_parameters'
                try {
                    $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                    $Task
                    [array]$AllTask += $Task
                }
                catch {
                    Write-Warning "$($_.Exception.Message), failed to set credentials for VM $VM"
                }
            }
        }
        else {
            foreach ($VM in $VmName) {
                if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
                    # Both forms of the policy command (set report) uses a hash containing VM Ids (specified)
                    try {
                        $VmList += Get-SvtVm -VmName $VM -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    }
                    catch {
                        throw $_.Exception.Message
                    }
                }
                else {
                    # Run a task to set user credentials on each VM (specified)
                    try {
                        $VmObj = Get-SvtVm -VmName $VM -ErrorAction Stop
                        $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmObj.VmId +
                        '/backup_parameters'
                    }
                    catch {
                        throw $_.Exception.Message
                    }
                    try {
                        $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                        $Task
                        [array]$AllTask += $Task
                    }
                    catch {
                        Write-Warning "$($_.Exception.Message), failed to set credentials for VM $VM"
                    }
                }
            } # end foreach
        } # end else
    }
    end {
        if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
            # Now we have a list of VM Ids, run the task (set or report policy)
            $Body = @{
                'virtual_machine_id' = $VmList
                'policy_id'          = $PolicyId
            } | ConvertTo-Json
            Write-Verbose $Body

            # run either the set or report API. URI set in begin block.
            try {
                $Response = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            if ($ImpactReportOnly) {
                # Schedule impact performed, show report
                Get-SvtImpactReport -Response $Response
            }
            else {
                #Task performed, show the task
                $Response
                $global:SvtTask = $Response
                $null = $SvtTask
            }
        }
        else {
            # Work for set user credentials is done in process loop, just output the task Ids
            $global:SvtTask = $AllTask
            $null = $SvtTask
        }
    } # end block
}

<#
.SYNOPSIS
    Stop a virtual machine hosted on HPE SimpliVity storage
.DESCRIPTION
    Stop a virtual machine hosted on HPE SimpliVity storage

    Stopping VMs with this command is not recommended. The VM will be in a "crash consistent" state.
    This action may lead to some data loss.

    A better option is to use the VMware PowerCLI Stop-VMGuest cmdlet. This shuts down the Guest OS gracefully.
.PARAMETER VmName
    The virtual machine name to stop
.PARAMETER VmId
    Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from
    the pipeline, using Get-SvtVm. This is more efficient (single call to the SimpliVity API).
.EXAMPLE
    PS C:\> Stop-SvtVm -VmName MyVm

    Stops the specified virtual machine
.EXAMPLE
    PS C:\> Get-SvtVm -Datastore DS01 | Stop-SvtVm

    Stops all the VMs on the specified datastore
.EXAMPLE
    PS C:\> Stop-SvtVm -VmName Win2019-01,Win2019-02,Win2019-03

    Stops the specified virtual machines
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtVm.md
#>
function Stop-SvtVm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String]$VmId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.11+json'
        }
    }

    process {
        if ($VmId) {
            $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmId + '/power_off'
            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), failed to stop VM $VmName"
            }
        }
        else {
            foreach ($VM in $VmName) {
                try {
                    # Getting VM name within the loop. Getting all VMs in the begin block might be a problem
                    # with a large number of VMs
                    $VmObj = Get-SvtVm -VmName $VM -ErrorAction Stop
                    $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmObj.VmId + '/power_off'
                }
                catch {
                    throw $_.Exception.Message
                }

                try {
                    $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                    $Task
                    [array]$AllTask += $Task
                }
                catch {
                    Write-Warning "$($_.Exception.Message), failed to stop VM $VM"
                }
            }
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SvtTask
        $global:SvtTask = $AllTask
        $null = $SvtTask # Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Start a virtual machine hosted on HPE SimpliVity storage
.DESCRIPTION
    Start a virtual machine hosted on HPE SimpliVity storage
.PARAMETER VmName
    The virtual machine name to start
.PARAMETER VmId
    Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from
    the pipeline, using Get-SvtVm. This is more efficient (single call to the SimpliVity API).
.EXAMPLE
    PS C:\> Start-SvtVm -VmName MyVm

    Starts the specified virtual machine
.EXAMPLE
    PS C:\> Get-SvtVm -ClusterName DR01 | Start-SvtVm -VmName MyVm

    Starts the virtual machines in the specified cluster
.EXAMPLE
    PS C:\> Start-SvtVm -VmName Win2019-01,Linux-01

    Starts the specified virtual machines
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    Author: Roy Atkins, HPE Pointnext Services
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Start-SvtVm.md
#>
function Start-SvtVm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [System.String]$VmId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SvtConnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.11+json'
        }
    }

    process {
        if ($VmId) {
            $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmId + '/power_on'
            try {
                $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), failed to stop VM $VmName"
            }
        }
        else {
            foreach ($VM in $VmName) {
                try {
                    # Getting VM name within the loop. Getting all VMs in the begin block might be a problem
                    # with a large number of VMs
                    $VmObj = Get-SvtVm -VmName $VM -ErrorAction Stop
                    $Uri = $global:SvtConnection.VA + '/api/virtual_machines/' + $VmObj.VmId + '/power_on'
                }
                catch {
                    throw $_.Exception.Message
                }

                try {
                    $Task = Invoke-SvtRestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                    $Task
                    [array]$AllTask += $Task
                }
                catch {
                    Write-Warning "$($_.Exception.Message), failed to start VM $VM"
                }
            }
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SvtTask
        $global:SvtTask = $AllTask
        $null = $SvtTask #Stops PSScriptAnalyzer complaining about variable assigned but never used
    }
}

#endregion VirtualMachine
