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
$HPESimplivityVersion = '2.1.25'

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

#region Utility

# Helper function for most cmdlets that accept a hostname parameter. The user supplied hostname(s) 
# is/are compared to an object containing a valid hostname property. (e.g. Get-SVThost and Get-SVThardware 
# both have this)
function Resolve-SVTFullHostName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String[]]$HostName,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [System.String[]]$ReferenceHost
    )

    begin {
        [System.String[]]$HostNotFound = @()
        [System.String[]]$ReturnHost = @()
    }

    process {
        foreach ($ThisHost in $HostName) {
            $TestHost = $ReferenceHost | Where-Object { $_ -eq $ThisHost }
            
            if (-not $TestHost) {
                $Message = "Specified host $ThisHost not found, attempting to match host " +
                'name without domain suffix'
                Write-Verbose $Message
                
                $TestHost = $ReferenceHost | 
                Where-Object { $_.Split('.')[0] -eq $ThisHost }
            }

            if ($TestHost) {
                $ReturnHost += $TestHost
            }
            else {
                $HostNotFound += $ThisHost
            }
        }
    }

    end {
        if ($ReturnHost) {
            # found at least one host
            if ($HostNotFound) {
                Write-Warning "The following host(s) not found: $($HostNotFound -join ', ')"
            }
            $ReturnHost | Sort-Object | Select-Object -Unique
        }
        else {
            throw 'Specified host(s) not found'
        }
    }
}

# Helper function to return the embedded error message in the body of the response from the API, rather
# than a generic runtime (400,404) error. Called exclusively by Invoke-SVTrestMethod.
function Get-SVTerror {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Err
    )

    if ($PSEdition -eq 'Core') {
        # PowerShell Core editions has the embedded error availble in ErrorDetails property.
        if ($Err.ErrorDetails.Message) {
            $ResponseBody = $Err.ErrorDetails.Message
            if ($ResponseBody.StartsWith('{')) {
                $ResponseBody = $ResponseBody | ConvertFrom-Json
            }
            return $ResponseBody.Message
        }
        else {
            return $_.Exception.Message
        }
    }
    else {
        # Windows PowerShell doesn't have this. Use GetResponseStreams() method.
        if ($Err.Exception.Response) {
            $Result = $Err.Exception.Response.GetResponseStream()
            $Reader = New-Object System.IO.StreamReader($Result)
            $Reader.BaseStream.Position = 0
            $Reader.DiscardBufferedData()
            $ResponseBody = $Reader.ReadToEnd()
            if ($ResponseBody.StartsWith('{')) {
                $ResponseBody = $ResponseBody | ConvertFrom-Json
            }
            return $ResponseBody.Message
        }
        else {
            return $_.Exception.Message
        }
    }
}

# Helper function that returns the local date format. Used directly by Get-SVTbackup and indirectly by other 
# cmdlets via ConvertFrom-SVTutc.
function Get-SVTLocalDateFormat {
    # Format dates with the local culture, except that days, months and hours are padded with zero.
    # (Some cultures use single digits)
    $Culture = (Get-Culture).DateTimeFormat
    $DateFormat = "$($Culture.ShortDatePattern)" -creplace '^d/', 'dd/' -creplace '^M/', 'MM/' -creplace '/d/', '/dd/'
    $TimeFormat = "$($Culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm', 'HH:mm'
    return "$DateFormat $TimeFormat"
}

# Helper function that returns the local date/time given the UTC (system) date/time. Used by cmdlets that return 
# date properties.
# Note: Dates are handled differently across PowerShell editions. With Desktop, dates in the UTC format are 
# correctly left as strings (e.g. '2020-06-03T22:00:00Z' ) when converting json to a PSobject. However, with Core, 
# UTC formatted dates are incorrectly converted to the local date/time (e.g. 03/06/2020 22:00:00, ignoring UTC 
# offset). In the former case, its easy to convert to local time as the date is formatted for the local culture.
# In the latter case, the UTC date/time must be converted to local date/time first and then formatted. This
# behavior may change in future versions of Core.
function ConvertFrom-SVTutc {
    [CmdletBinding()]
    Param (
        # string or date object
        [Parameter(Mandatory = $true, Position = 0)]
        $Date
    )

    if ($Date -as [datetime]) {
        $LocalFormat = Get-SVTLocalDateFormat
        if ($PSEdition -eq 'Core') {
            $TimeZone = [System.TimeZoneInfo]::Local
            $LocalDate = [System.TimeZoneInfo]::ConvertTimeFromUtc($Date, $TimeZone)
            $ReturnDate = Get-Date -Date $LocalDate -Format $LocalFormat
        }
        else {
            $ReturnDate = Get-Date -Date $Date -Format $LocalFormat
        }
        #$Message = "UTC: $Date ($(($date).GetType().FullName)), Local: $ReturnDate ($(($ReturnDate).GetType().FullName))"
        #Write-Verbose $Message
        return $ReturnDate
    }
    else {
        # The API returns 'NA' to represent null values.
        return $null
    }
}

# Helper function used by Get/New/Copy-SVTbackup and New/Update-SVTpolicyRule to return the backup 
# destination. This must be a cluster or an external store. Otherwise throw an error.
Function Get-SVTbackupDestination {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String[]]$DestinationName
    )

    [bool]$FoundCluster = $false
    [bool]$FoundExternalStore = $false
    [array]$DestinationNotFound = @()
    [array]$ReturnObject = @()

    foreach ($Destination in $DestinationName) {
        try {
            $Dest = Get-SVTcluster -Name $Destination -ErrorAction Stop
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
                throw 'Destinations must be of type cluster or external store, not both'
            }
            else {
                # Get-SVTcluster must have failed. Try External Store
            }
        }

        try {
            $Dest = Get-SVTexternalStore -Name $Destination -ErrorAction Stop
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
                throw 'Destinations must be of type cluster or external store, not both'
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
        throw 'Invalid destination name specified. Enter a valid cluster or external store name.'
    }
}

# Helper function for Invoke-RestMethod to handle all REST requests and errors in one place. 
# This cmdlet either returns a HPE.SimpliVity.Task object if the REST API response is a task object, 
# or otherwise the raw JSON for the calling function to deal with.
function Invoke-SVTrestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Uri,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.Collections.IDictionary]$Header,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('get', 'post', 'delete', 'put')]
        [System.String]$Method,

        [Parameter(Mandatory = $false, Position = 3)]
        [System.Object]$Body
    )

    [System.int32]$Retrycount = 0
    [bool]$Stoploop = $false

    do {
        try {
            #$Param = $PSBoundParameters | ConvertTo-Json
            #Write-Verbose $Param
            if ($PSEdition -eq 'Core' -and -not $SVTconnection.SignedCertificate) {
                # PowerShell Core without a signed cert
                $Response = Invoke-RestMethod @PSBoundParameters -SkipCertificateCheck
            }
            else {
                # Windows PowerShell (with or without a signed cert) or PowerShell Core with a signed cert
                $Response = Invoke-RestMethod @PSBoundParameters
            }
            $Stoploop = $true
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
                    $OVC = $SVTconnection.OVC -replace 'https://', ''
                    $Retry = Connect-SVT -OVC $OVC -Credential $SVTconnection.Credential

                    # Update the json header authorisation with the new token for the retry,
                    # not the entire header; this breaks subsequent POST calls.
                    $Header.Authorization = "Bearer $($Retry.Token)"
                }
            }
            elseif ($_.Exception.Message -match 'The hostname could not be parsed') {
                throw 'Runtime error: You must first log in using Connect-SVT'
            }
            else {
                #throw "Runtime error: $($_.Exception.Message)"
                # Return the embedded error message in the body of the response from the API
                throw "Runtime error: $(Get-SVTerror($_))"
            }
        }
        catch {
            throw "An unexpected error occurred: $($_.Exception.Message)"
        }
    }
    until ($Stoploop -eq $true)

    # If the JSON output is a task, convert it to a custom object of type 'HPE.SimpliVity.Task' and pass this 
    # back to the calling cmdlet.
    # Note: $Response.task is incorrectly true with /api/omnistack_clusters/throughput, so added a check for this.
    if ($Response.task -and $URI -notmatch '/api/omnistack_clusters/throughput') {
        $Response.task | ForEach-Object {
            [PSCustomObject]@{
                PStypeName      = 'HPE.SimpliVity.Task'
                StartTime       = ConvertFrom-SVTutc -Date $_.start_time
                AffectedObjects = $_.affected_objects
                OwnerId         = $_.owner_id
                DestinationId   = $_.destination_id
                Name            = $_.name
                EndTime         = ConvertFrom-SVTutc -Date $_.end_time
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
    Show information about tasks that are currently executing or have finished executing in an 
    HPE SimpliVity environment
.DESCRIPTION
    Performing most Post/Delete calls to the SimpliVity REST API will generate task objects as output.
    Whilst these task objects are immediately returned, the task themselves will change state over time. 
    For example, when a Clone VM task completes, its state changes from IN_PROGRESS to COMPLETED.

    All cmdlets that return a JSON 'task' object, (e.g. New-SVTbackup and New-SVTclone) will output custom task 
    objects of type HPE.SimpliVity.Task and can then be used as input here to find out if the task completed 
    successfully. You can either specify the Task ID from the cmdlet output or, more usefully, use $SVTtask. 
    This is a global variable that all 'task producing' HPE SimpliVity cmdlets create. $SVTtask is 
    overwritten each time one of these cmdlets is executed.
.PARAMETER Task
    The task object(s). Use the global variable $SVTtask which is generated from a 'task producing' 
    HPE SimpliVity cmdlet, like New-SVTbackup, New-SVTclone and Move-SVTvm.
.PARAMETER Id
    Specify a valid task ID
.INPUTS
    HPE.SimpliVity.Task
.OUTPUTS
    HPE.SimpliVity.Task
.EXAMPLE
    PS C:\> Get-SVTtask

    Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates 
    a SimpliVity resource
.EXAMPLE
    PS C:\> New-SVTbackup -VmName MyVm
    PS C:\> Get-SVTtask

    Show the current state of the task executed from the New-SVTbackup cmdlet.
.EXAMPLE
    PS C:\> New-SVTclone Server2016-01 NewServer2016-01
    PS C:\> Get-SVTtask | Format-List

    The first command clones the specified VM.
    The second command monitors the progress of the clone task, showing all the task properties.
.EXAMPLE
    PS C:\> Get-SVTtask -ID d7ef1442-2633-...-a03e69ae24a6

    Displays the progress of the specified task ID. This command is useful when using the Web console to 
    test REST API calls
.NOTES
#>
function Get-SVTtask {
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeLine = $true, ParameterSetName = 'ByObject')]
        [System.Object]$Task = $SVTtask,

        [Parameter(Mandatory = $false, ParameterSetName = 'ById')]
        [String]$Id
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
        }
        if ($PSboundParameters.ContainsKey('Id')) {
            $Task = @{ TaskId = $Id }
        }
    }

    process {
        foreach ($ThisTask in $Task) {
            $Uri = $global:SVTconnection.OVC + '/api/tasks/' + $ThisTask.TaskId

            try {
                Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
    }
}



<#
.SYNOPSIS
    Connect to a HPE SimpliVity OmniStack Virtual Controller (OVC) or Managed Virtual Appliance (MVA)
.DESCRIPTION
    To access the SimpliVity REST API, you need to request an authentication token by issuing a request
    using the OAuth authentication method. Once obtained, you can pass the resulting access token via the
    HTTP header using an Authorisation Bearer token.

    The access token is stored in a global variable accessible to all HPESimpliVity cmdlets in the PowerShell 
    session. Note that the access token times out after 10 minutes of inactivity. However, the HPEsimpliVity 
    module will automatically recreate a new token using cached credentials. 
.PARAMETER OVC
    The Fully Qualified Domain Name (FQDN) or IP address of any OmniStack Virtual Controller (or MVA). 
    This is the management IP address of the OVC / MVA.
.PARAMETER Credential
    User generated credential as System.Management.Automation.PSCredential. Use the Get-Credential 
    PowerShell cmdlet to create the credential. This can optionally be imported from a file in cases where 
    you are invoking non-interactively. E.g. shutting down the OVC's from a script invoked by UPS software.
.PARAMETER SignedCert
    Requires a trusted certificate to enable TLS1.2. By default, the cmdlet allows untrusted certificates with 
    HTTPS connections. This is, most commonly, a self-signed certificate. Alternatively it could be a 
    certificate issued from an untrusted certificate authority, such as an internal CA.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.EXAMPLE
    PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC>

    This will securely prompt you for credentials
.EXAMPLE
    PS C:\> $Cred = Get-Credential -Message 'Enter Credentials'
    PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $Cred

    Create the credential first, then pass it as a parameter.
.EXAMPLE
    PS C:\> $CredFile = "$((Get-Location).Path)\OVCcred.XML"
    PS C:\> Get-Credential -Credential '<username@domain>'| Export-CLIXML $CredFile

    Another way is to store the credential in a file (as above), then connect to the OVC using:
    PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $(Import-CLIXML $CredFile)

    or:
    PS C:\> $Cred = Import-CLIXML $CredFile
    PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $Cred

    This method is useful in non-interactive sessions. Once the file is created, run the Connect-SVT
    command to connect and reconnect to the OVC, as required.
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Connect-SVT.md

#>
function Connect-SVT {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('VirtualController', 'VC', 'Name')]
        [System.String]$OVC,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Management.Automation.PSCredential]$Credential,

        [Switch]$SignedCert
    )

    $Header = @{
        'Authorization' = 'Basic ' + 
        [System.Convert]::ToBase64String([System.Text.UTF8Encoding]::UTF8.GetBytes('simplivity:'))

        'Accept'        = 'application/json'
    }
    $Uri = 'https://' + $OVC + '/api/oauth/token'

    if ($SignedCert) {
        # User has specified -SignedCert, so the OVC/MVA must have a certificate which is trusted by the client 
    }
    else {
        # Effectively bypass TLS by trusting all certificates. Works with untrusted, self-signed certs and is the 
        # default. Ideally, customers should install trusted certificates, but this is rarely implemented.
        if ($PSEdition -eq 'Core') {
            # With PowerShell Core, Invoke-RestMethod supports -SkipCerticateCheck. The global $SVTConnection
            # variable has a 'SignedCertificate' property set here, used by Invoke-SVTrestMethod. 
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
        $OVCcred = $Credential
    }
    else {
        $OVCcred = Get-Credential -Message 'Enter credentials with authorisation to login ' +
        'to your OmniStack Virtual Controller (e.g. administrator@vsphere.local)'
    }

    $Body = @{
        'username'   = $OVCcred.Username
        'password'   = $OVCcred.GetNetworkCredential().Password
        'grant_type' = 'password'
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $global:SVTconnection = [pscustomobject]@{
        OVC               = "https://$OVC"
        Credential        = $OVCcred
        Token             = $Response.access_token
        UpdateTime        = $Response.updated_at
        Expiration        = $Response.expires_in
        SignedCertificate = $SignedCert.IsPresent
    }
    # Return connection object to the pipeline. Used by all other HPESimpliVity cmdlets.
    $global:SVTconnection
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
    PS C:\> Get-SVTversion

    Shows version information for the REST API and SVTFS. It also shows whether you are
    connecting to an Omnistack Virtual Appliance (OVA) or a Managed Virtual Appliance (MVA).
.NOTES
#>
function Get-SVTversion {
    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/version'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    if ($Response.SVTFS_Version) {
        $Controller = 'OmniStack Virtual Controller'
    }
    else {
        $Controller = 'Managed Virtual Appliance'
    }

    $Response | ForEach-Object {
        [PSCustomObject]@{
            'RestApiVersion'          = $_.REST_API_Version
            'SvtFsVersion'            = $_.SVTFS_Version
            'PowerShellModuleVersion' = $HPESimplivityVersion
            'ControllerType'          = $Controller
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

    In addition, output from the Get-SVTcluster, Get-Host and Get-SVTvm commands is accepted as input.
.PARAMETER SVTobject
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
    PS C:\> Get-SVTmetric -ClusterName Production

    Shows performance metrics about the specified cluster, using the default hour setting (24 hours) and 
    resolution (every hour)
.EXAMPLE
    PS C:\> Get-SVThost | Get-SVTmetric -Hour 1 -Resolution SECOND

    Shows performance metrics for all hosts in the federation, for every second of the last hour
.EXAMPLE
    PS C:\> Get-SVTvm | Where VmName -match "SQL" | Get-SVTmetric

    Show performance metrics for every VM that has "SQL" in its name
.EXAMPLE
    PS C:\> Get-SVTcluster -ClusterName DR | Get-SVTmetric -Hour 1440 -Resolution DAY

    Show daily performance metrics for the last two months for the specified cluster
.EXAMPLE
    PS C:\> Get-SVTvm Vm1,Vm2,Vm3 | Get-Metric -Chart -Verbose

    Create chart(s) instead of showing the metric data. Chart files are created in the current folder.
    Use filtering when creating charts for virtual machines to avoid creating a lot of charts.
.EXAMPLE
    PS C:\> Get-SVThost -Name MyHost | Get-Metric -Chart | Foreach-Object {Invoke-Item $_}

    Create a metrics chart for the specified host and immediately display it. Note that Invoke-Item 
    only works with image files when the Desktop Experience Feature is installed (may not be installed 
    on some servers)
.EXAMPLE
    PS C:\> Get-SVTmetric -Cluster SVTcluster -Chart -ChartProperty IopsRead,IopsWrite

    Create a metrics chart for the specified cluster showing only the specified properties. By default
    the last day is shown (-Hour 24) with a resolution of MINUTE (-Resolution MINUTE).
.EXAMPLE
    PS C:\> Get-SVTmetric -Host server1 -Chart -OffsetHour 24

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
    With the -Chart parameter, there is a known issue with PowerShell V7.0.1, an exception calling "SaveImage", 
    could not load file or assembly when trying to save a chart to a file. PowerShell V5.1, V7.0.0 and
    V7.1.0-Preview3 work as expected.
#>
function Get-SVTmetric {
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
            ParameterSetName = 'SVTobject')]
        [System.Object]$SVTobject,

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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
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
        if ($PSBoundParameters.ContainsKey('SVTobject')) {
            $InputObject = $SVTObject
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
                $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $Item.ClusterId + '/metrics'
                $ObjectName = $Item.ClusterName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.Host') {
                $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $Item.HostId + '/metrics'
                $ObjectName = $Item.HostName
            }
            elseif ($TypeName -eq 'HPE.SimpliVity.VirtualMachine') {
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $Item.VmId + '/metrics'
                $ObjectName = $Item.VmName
            }
            elseif ($PSBoundParameters.ContainsKey('VmName')) {
                try {
                    $VmId = Get-SVTvm -VmName $Item -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/metrics'
                    $ObjectName = $Item
                    $TypeName = 'HPE.SimpliVity.VirtualMachine'
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            elseif ($PSBoundParameters.ContainsKey('HostName')) {
                try {
                    $HostId = Get-SVThost -HostName $Item -ErrorAction Stop | 
                    Select-Object -ExpandProperty HostId
                    
                    $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/metrics'
                    $ObjectName = $Item
                    $TypeName = 'HPE.SimpliVity.Host'
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                # This is deliberately a catchall. $SVTobject could be passed in as a string, e.g.
                # 'Cluster01' | Get-SVTmetric
                try {
                    $Cluster = Get-SVTcluster -ClusterName $Item -ErrorAction Stop
                    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $Cluster.ClusterId + '/metrics'
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
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This returns each Metric with a date and some values
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = (Get-Culture).TextInfo.ToTitleCase($_.name)
                $_.data_points | ForEach-Object {
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = ConvertFrom-SVTutc -Date $_.date
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
                    PStypeName = 'HPE.SimpliVity.Metric'
                    Date       = $_.Name
                }

                [string]$prevname = ''
                $_.Group | Foreach-object {
                    # We expect one instance each of Iops, Latency and Throughput per date. 
                    # But sometimes the API returns more. Attempting to create a key that already 
                    # exists generates a non-terminating error so, check for duplicates.
                    if ($_.name -ne $prevname) {
                        $Property += [ordered]@{
                            "$($_.Name)Read"  = $_.Read
                            "$($_.Name)Write" = $_.Write
                        }
                    }
                    $prevname = $_.Name
                }
               
                $Property += [ordered]@{
                    ObjectType = $TypeName
                    ObjectName = $ObjectName
                }
                New-Object -TypeName PSObject -Property $Property
            }

            if ($PSBoundParameters.ContainsKey('Chart')) {
                [array]$ChartObject += $MetricObject
            }
            else {
                $MetricObject
            }
        } #end for
    } #end process

    end {
        if ($PSBoundParameters.ContainsKey('Chart')) {
            Get-SVTmetricChart -Metric $ChartObject -ChartProperty $ChartProperty
        }
    }
}

# Helper function for Get-SVTmetric
function Get-SVTmetricChart {
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
    $Logo = (split-path -parent (get-module HPEsimpliVity -ListAvailable).Path) + '\hpe.png'

    # define an object to determine the best interval on the Y axis, given a maximum value
    $Ymax = (0, 2500, 5000, 10000, 20000, 40000, 80000, 160000, 320000, 640000, 1280000, 2560000, 5120000, 10240000, 20480000)
    $Yinterval = (100, 200, 400, 600, 1000, 5000, 10000, 15000, 20000, 50000, 75000, 100000, 250000, 400000, 1000000)
    $Yaxis = 0..14 | ForEach-Object {
        [PSCustomObject]@{
            Maximum  = $Ymax[$_]
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
            $ShortName = ([ipaddress]$Instance).IPAddressToString
        }
        catch {
            # the object name is not an IP address
            $ShortName = $Instance -split '\.' | Select-Object -First 1
        }
        $null = $Chart1.Titles.Add("$($TypeName): $ShortName - Metrics from $StartDate to $EndDate")
        $Chart1.Titles[0].Font = New-Object System.Drawing.Font [System.Drawing.Font.Fontfamily]::Arial, 16
        $Chart1.Titles[0].Alignment = 'topLeft'

        # add chart area, axistype is required to create primary and secondary yaxis
        $AxisEnabled = New-Object System.Windows.Forms.DataVisualization.Charting.AxisEnabled
        $AxisType = New-Object System.Windows.Forms.DataVisualization.Charting.AxisType
        $Area1 = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Area1.Name = 'ChartArea1'
        $Area1.AxisX.Title = 'Date'
        $Area1.AxisX.TitleFont = $ChartTitleFont
        $Area1.AxisX.LabelStyle.Font = $ChartLabelFont
        $Area1.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray

        # show a maximum of 24 labels on the xaxis
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
            $Yaxis | ForEach-Object {
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
            $Chart1.SaveImage("$Path\SVTmetric-$ShortName-$DateStamp.png", 'png')
            Get-ChildItem "$Path\SVTmetric-$ShortName-$DateStamp.png" -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
            #throw "Could not create $Path\SVTmetric-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SVTcapacity
function Get-SVTcapacityChart {
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
    $Logo = (split-path -parent (get-module hpesimplivity -ListAvailable).Path) + '\hpe.png'

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
        $Area3Dstyle = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea3DStyle
        $Area3Dstyle.Enable3D = $true
        $Area3Dstyle.LightStyle = 1
        $Area3Dstyle.Inclination = 20
        $Area3Dstyle.Perspective = 0

        $Area1 = $Chart1.ChartAreas.Add('ChartArea1')
        $Area1.Area3DStyle = $Area3Dstyle

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
            $Chart1.SaveImage("$Path\SVTcapacity-$ShortName-$DateStamp.png", 'png')
            Get-ChildItem "$Path\SVTcapacity-$ShortName-$DateStamp.png" -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
            #throw "Could not create $Path\SVTcapacity-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SVTdisk
# Notes: This method works quite well when all the disks are the same capacity. The 380 H introduces a bit
# of a problem. As long as the disks are sorted by slot number (i.e. the first disk will always be an SSD), 
# then the 380H disk capacity will be 1.92TB - the first disk is used to confirm the server type. This 
# method may break if additional models continue to be added.
# G (all flash) and H are both software optimized models.
function Get-SVTmodel { 
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

# Helper function for New-SVTpolicyRule, Remove-SVTpolicyRule, Update-SVTpolicyRule and Set-SVTvm
function Get-SVTimpactReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Object]$Response
    )
    $TextInfo = (Get-Culture).TextInfo
    foreach ($Attribute in $Response.schedule_before_change.PSobject.Properties.Name) {
        [PSCustomObject]@{
            'Attribute'    = $TextInfo.TotitleCase($Attribute) -replace '_', ''
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
    an offset value with limit set to 3000). It is recommended to use other parameters with the -All parameter 
    to limit the output.

    Multiple values can be used for most parameters, but only when connecting to a Managed Virtual Appliance. 
    Multi-value parameters currently fail when connected to an Omnistack Virtual Controller.
.PARAMETER VmName
    Show all backups for the specified virtual machine(s). By default a limit of 500 backups are shown, but
    this can be increased.
.PARAMETER ClusterName
    Show all backups sourced from a specified HPE SimpliVity cluster name or names. By default a limit of 500 
    backups are shown, but this can be increased.
.PARAMETER DataStoreName
    Show all backups sourced from a specified SimpliVity datastore or datastores. By default a limit of 500 
    backups are shown, but this can be increased.
.PARAMETER DestinationName
    Show backups located on the specified destination HPE SimpliVity cluster name or external datastore name.
    Multiple destinations can be specified, but they must all be of one type (i.e. cluster or external store)
    By default a limit of 500 backups are shown, but this can be increased.
.PARAMETER BackupId
    Show the backup with the specified backup ID only.
.PARAMETER BackupName
    Show backups with the specified backup name only.
.PARAMETER BackupState
    Show backups with the specified state. i.e PROTECTED, FAILED or SAVING
.PARAMETER BackupType
    Show backups with the specified type. i.e. MANUAL or POLICY
.PARAMETER MinSizeMB
    Show backups with the specified minimum size
.PARAMETER MaxSizeMB
    Show backups with the specified maximum size
.PARAMETER Date
    Display backups created on the specified date. This takes precedence over CreatedAfter and CreatedBefore.
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
    PS C:\> Get-SVTbackup

    Show the last 24 hours of backups from the SimpliVity Federation.
.EXAMPLE
    PS C:\> Get-SVTbackup -Date 04/04/2020
    PS C:\> Get-SVTBackup -Date 04/04/2020 -VmName Server2016-04

    The first command show all backups from the specified date, up to the default limit of 500 backups.
    The second command show all backups from the specified date for a specific virtual machine.
.EXAMPLE
    PS C:\> Get-SVTbackup -CreatedAfter "04/04/2020 10:00am" -CreatedBefore "04/04/2020 02:00pm"

    Show backups created between the specified dates/times. (using local date/time format). Limited to 500 
    backups by default.
.EXAMPLE
    PS C:\> Get-SVTbackup -ExpiresAfter "04/04/2020" -ExpiresBefore "05/04/2020" -Limit 100

    Show backups that will expire between the specified dates/times. (using local date/time format). Limited to 
    display up to 100 backups.
.EXAMPLE
    PS C:\> Get-SVTbackup -Hour 48 -Limit 1000 | 
        Select-Object VmName, DataStoreName, SentMB, UniqueSizeMB | Format-Table -Autosize

    Show backups up to 48 hours old and display specific properties. Limited to display up to 1000 backups.
.EXAMPLE
    PS C:\> Get-SVTbackup -All

    Shows all backups with no limit. This command may take a long time to complete because it makes multiple
    calls to the SimpliVity API until all backups are returned. It is recommended to use other parameters 
    restrict the number of backups returned.
.EXAMPLE
    PS C:\> Get-SVTbackup -Datastore DS01 -All

    Shows all backups for the specified Datastore with no upper limit. This command will take a long time 
    to complete.
.EXAMPLE
    PS C:\> Get-SVTbackup -VmName Vm1,Vm2 -BackupName 2020-03-28T16:00+10:00 
    PS C:\> Get-SVTbackup -VmName Vm1,Vm2,Vm3 -Hour 2 -Limit 1

    The first command shows backups for the specified VMs with the specified backup name.
    The second command shows the last backup taken within the last 2 hours for each specified VM.
    The use of multiple, comma separated values works when connected to a Managed Virtual Appliance only. 
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname VM1 -BackupName '2019-04-26T16:00:00+10:00'

    Display the backup for the specified virtual machine in the specified backup
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname VM1 -BackupName '2019-05-05T00:00:00-04:00' -DestinationName SVTcluster

    If you have backup policies with more than one rule, further refine the filter by specifying the destination
    SimpliVity cluster or external store.
.EXAMPLE
    PS C:\> Get-SVTbackup -Datastore DS01,DS02 -Limit 1000

    Shows all backups on the specified SimpliVity datastores, up to the specified limit
.EXAMPLE
    PS C:\> Get-SVTbackup -ClusterName cluster1 -Limit 100
    PS C:\> Get-SVTbackup -ClusterName cluster1 -Limit 1 -Verbose

    The first command shows the most recent 100 backups for all VMs located on the specified cluster.
    The second command shows a quick way to determine the number of backups on a cluster without showing them
    all. The verbose message will always display the number of backups that meet the command criteria.
.EXAMPLE
    PS C:\> Get-SVTbackup -DestinationName cluster1

    Show backups located on the specified cluster or external store.

    You can specify multiple destinations, but they must all be of the same type. i.e. SimpliVity clusters
    or external stores.
.EXAMPLE
    PS C:\> Get-SVTbackup -DestinationName StoreOnce-Data02,StoreOnce-Data03 -ExpireAfter 31/12/2020

    Shows backups on the specified external datastores that will expire after the specified date (using local 
    date/time format)
.EXAMPLE
    Get-SVTbackup -BackupState FAILED -Limit 20

    Show a list of failed backups, limited to 20 backups.
.EXAMPLE
    Get-SVTbackup -Datastore DS01 -BackupType MANUAL

    Show a list of backups that were manually taken for VMs residing on the specified datastore.
.EXAMPLE
    PS C:\> Get-SVTvm -ClusterName cluster1 | Foreach-Object { Get-SVTbackup -VmName $_.VmName -Limit 1 }
    PS C:\> Get-SVTvm -Name Vm1,Vm2,Vm3 | Foreach-Object { Get-SVTbackup -VmName $_.VmName -Limit 1 }

    Display the latest backup for each specified VM
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Backup
.NOTES
Known issues with the REST API Get operations for Backup objects:
 1. OMNI-53190 REST API Limit recommendation for REST GET backup object calls.
 2. OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints.
 3. Filtering on a cluster destination also displays external store backups. This issue applies when connected to 
Omnistack virtual controllers only. It works as expected when connected to a Managed Virtual Appliance.
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTbackup.md
#>
function Get-SVTbackup {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }
    $LocalFormat = Get-SVTLocalDateFormat
    $LocalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    $Offset = 0

    # Case sensitivity is problematic with /backups API. Some properties do not support case insensitive 
    # filter, so assuming case sensitive for all.
    $Uri = "$($global:SVTconnection.OVC)/api/backups?case=sensitive"

    if ($PSBoundParameters.ContainsKey('All')) {
        $Message = 'This command may take a long time to complete. Consider using other parameters ' +
        'with -All to limit output'
        Write-Warning $Message
        $Limit = 3000
        $Uri += "&limit=$Limit"
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
            $Destination = Get-SVTbackupDestination -Name $DestinationName -ErrorAction Stop
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
        # add an asterix to each backupname to support incomplete name match. Also replace plus symbol
        $Uri += "&name=$(($BackupName -join '*,') + '*' -replace '\+', '%2B')"
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
        $Message = 'The Date parameter takes precedence over the CreatedAfter and CreatedBefore parameters'
        Write-Verbose $Message
        $StartDate = Get-Date -Date "$Date"
        $EndDate = (Get-Date -Date $StartDate).AddMinutes(1439)
        $After = "$(Get-Date $($StartDate.ToUniversalTime()) -format s)Z"
        $Before = "$(Get-Date $($EndDate.ToUniversalTime()) -format s)Z"
        $Uri += "&created_before=$Before&created_after=$After"
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
    if ($PSBoundParameters.ContainsKey('Hour')) {
        # Ignore -Hour if any other date related parameter is specified
        $ParamList = @('Date', 'CreatedAfter', 'CreatedBefore', 'ExpiresAfter', 'ExpiresBefore')
        $ParamFound = @()
        foreach ($Param in $ParamList) {
            if ($Param -in $PSBoundParameters.Keys) {
                $ParamFound += $Param
            }
        }
        if ($ParamFound) {
            $Message = "$($ParamFound -join ',') specified, ignoring Hour parameter"
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
        # common parameters, which would affect the behavior. -Limit is allowed.
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
            $Response = Invoke-SVTrestMethod -Uri $ThisUri -Header $Header -Method Get -ErrorAction Stop
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

        if (-not $Response.Backups.Name) {
            if ($PSBoundParameters.ContainsKey('VmName')) {
                throw "Backups for specified virtual machine(s) $VmName not found"
            }
            if ($PSBoundParameters.ContainsKey('ClusterName')) {
                throw "Backups with specified cluster $ClusterName not found"
            }
            if ($PSBoundParameters.ContainsKey('DatastoreName')) {
                throw "Backups with specified datastore $DatastoreName not found"
            }
            if ($PSBoundParameters.ContainsKey('DestinationName')) {
                throw "Backups with specified destination $DestinationName not found"
            }
            if ($PSBoundParameters.ContainsKey('BackupName')) {
                throw "Specified backup name(s) $BackupName* not found"
            }
            if ($PSBoundParameters.ContainsKey('BackupId')) {
                throw "Specified backup ID(s) $BackupId not found"
            }
        }

        $Response.backups | ForEach-Object {
            if ($_.omnistack_cluster_name) {
                $Destination = $_.omnistack_cluster_name
            }
            else {
                $Destination = $_.external_store_name
            }

            # Converting numeric strings to numbers so that sorting is possible. Must use locale to format correctly
            [PSCustomObject]@{
                PSTypeName        = 'HPE.SimpliVity.Backup'
                VmName            = $_.virtual_machine_name
                CreateDate        = ConvertFrom-SVTutc -Date $_.created_at
                ConsistencyType   = $_.consistency_type
                BackupType        = $_.type
                DataStoreName     = $_.datastore_name
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
                UniqueSizeDate    = ConvertFrom-SVTutc -Date $_.unique_size_timestamp
                ExpiryDate        = ConvertFrom-SVTutc -Date $_.expiration_time
                ClusterName       = $_.omnistack_cluster_name
                SentMB            = [single]::Parse('{0:n0}' -f ($_.sent / 1mb), $LocalCulture)
                SizeGB            = [single]::Parse('{0:n2}' -f ($_.size / 1gb), $LocalCulture)
                SizeMB            = [single]::Parse('{0:n0}' -f ($_.size / 1mb), $LocalCulture)
                VmState           = $_.virtual_machine_state
                BackupName        = $_.name
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
    via the VmName parameter or use Get-SVTvm output to pass in the HPE SimpliVity VM objects to backup. 
    Backups are directed to the specified destination cluster or external store, or to the local cluster 
    for each VM if no destination name is specified.
.PARAMETER VmName
    The virtual machine(s) to backup. Optionally use the output from Get-SVTvm to provide the required VM names. 
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
    PS C:\> New-SVTbackup -VmName MyVm -DestinationName ClusterDR

    Backup the specified VM to the specified SimpliVity cluster, using the default backup name and retention
.EXAMPLE
    PS C:\> New-SVTbackup MyVm StoreOnce-Data01 -RetentionDay 365 -ConsistencyType DEFAULT

    Backup the specified VM to the specified external datastore, using the default backup name and retain the
    backup for 1 year. A consistency type of DEFAULT creates a VMware snapshot to quiesce the disk prior to 
    taking the backup
.EXAMPLE
    PS C:\> New-SVTbackup -BackupName "BeforeSQLupgrade" -VmName SQL01 -DestinationName SVTcluster -RetentionHour 2

    Backup the specified SQL server with a backup name and a short (2 hour) retention
.EXAMPLE
    PS C:\> Get-SVTvm | ? VmName -match '^DB' | New-SVTbackup -BackupName 'Manual backup prior to SQL upgrade'

    Locally backup up all VMs with names starting with 'DB' using the specified backup name and with default 
    retention of 1 day.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function New-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VmName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$DestinationName,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$BackupName = "Created by $(($SVTconnection.Credential.Username -split '@')[0]) at " +
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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        if ($PSBoundParameters.ContainsKey('DestinationName')) {
            try {
                $Destination = Get-SVTbackupDestination -Name $DestinationName -ErrorAction Stop
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
                $VmObj = Get-SVTvm -VmName $VM -ErrorAction Stop
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmObj.VmId + '/backup'
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
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), backup failed for VM $VM" 
            }
        } #end foreach
    } #end process

    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Restore one or more HPE SimpliVity virtual machines
.DESCRIPTION
    Restore one or more virtual machines from backups hosted on HPE SimpliVity storage. Use Get-SVTbackup output 
    to pass in the backup(s) you want to restore. By default, a new VM is created for each backup passed in. The
    VMname is the same as the original with a timestamp appended. Alternatively, you can specify the 
    -RestoreToOriginal switch to overwrite existing virtual machine(s).

    However, if -NewVMname is specified, you can only pass in one backup. The first backup passed in will be
    restored with the specified VMname, but subsequent restores will not be attempted and an error is displayed.
    In addition, if you specify a new VM name that this is already in use by an existing VM, then the restore task 
    will fail.

    if -DatastoreName is not specified, then by default, the datastore used by the original VM(s) is/are used from
    each backup. If specified, then all restored VMs will be located on the specified datastore.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to 
    identify the backups you want to target and then pass the output to this command.
.PARAMETER RestoreToOriginal
    Specifies that the existing virtual machine is overwritten
.PARAMETER BackupId
    The UID of the backup(s) to restore from
.PARAMETER NewVMname
    A new name for the VM when restoring one VM only
.PARAMETER DatastoreName
    The destination datastore name. If not specified, the original datastore location in each backup is used
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName 2019-05-09T22:00:00+10:00 | Restore-SVTvm -RestoreToOriginal

    Restores the virtual machine(s) in the specified backup to the original VM(s)
.EXAMPLE
    PS C:\> Get-SVTbackup -VmName MyVm -Limit 1 | Restore-SVTvm

    Restores the most recent backup of specified virtual machine, giving it the name of the original VM with a 
    data stamp appended
.EXAMPLE
    PS C:\> Get-SVTbackup -VmName MyVm -Limit 1 | Restore-SVTvm -NewVMname MyOtherVM

    Restores the most recent backup of specified virtual machine, giving it the specfied name. NOTE: this command
    will only work for the first backup passed in. Subsequent restores are not attempted and an error is displayed.
.EXAMPLE
    PS> $LatestBackup = Get-SVTvm -VMname VM1,VM2,VM3 | Foreach-Object { Get-SVTbackup -VmName $_.VmName -Limit 1 }
    PS> $LatestBackup | Restore-SVTvm -RestoreToOriginal

    Restores the most recent backup of each specified virtual machine, overwriting the existing virtual machine(s)
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Restore-SVTvm {
    # calling this function 'restore VM' rather than 'restore backup' as per the API, because it makes more sense
    [CmdletBinding(DefaultParameterSetName = 'RestoreToOriginal')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'RestoreToOriginal')]
        [switch]$RestoreToOriginal,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'NewVm')]
        [Alias('VMname')]
        [System.String]$NewVMname,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelinebyPropertyName = $true,
            ParameterSetName = 'NewVm')]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $true, Position = 4, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $DateSuffix = Get-Date -Format 'yyMMddhhmmss'
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        if (-not $PSBoundParameters.ContainsKey('RestoreToOriginal')) {
            try {
                $Alldatastore = Get-SVTdatastore -ErrorAction Stop
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
                    $ThisBackup = Get-SVTbackup -BackupId $BkpId -ErrorAction Stop
                    if ($ThisBackup.ExternalStoreName) {
                        $Message = "Restoring VM $($ThisBackup.VmName) from a backup located on an external " +
                        "store with 'RestoreToOriginal' set is not supported"
                        throw $Message
                    }
                }
                catch {
                    # Don't exit, continue with other restores in the pipeline
                    Write-Error $_.Exception.Message
                    continue
                }
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/restore?restore_original=true'
            }
            else {
                # Not restoring to original and user specified a new VM Name
                if ($NewVMname) {
                    if ($Count -gt 1) { 
                        $global:SVTtask = $AllTask
                        throw "With multiple restores, you cannot specify a new VM name"
                    }
                    else {
                        # Works for the first VM in the pipeline only
                        Write-Verbose "Restoring VM with new name $NewVMname"
                        $RestoreVmName = $NewVMname
                    }
                }
                # Not restoring to original and no new name specified, so use existing VMnames with a timestamp suffix
                else {
                    try {
                        $VMname = Get-SVTbackup -BackupId $BkpId -ErrorAction Stop | 
                        Select-Object -ExpandProperty VmName
                    }
                    catch {
                        # Don't exit, continue with other restores in the pipeline
                        Write-Error $_.Exception.Message
                        continue
                    }
            
                    if ($VmName.Length -gt 59) {
                        $RestoreVmName = "$($VmName.Substring(0, 59))-restore-$DateSuffix"
                    }
                    else {
                        $RestoreVmName = "$VmName-restore-$DateSuffix"
                    }
                }
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/restore?restore_original=false'

                try {
                    $DataStoreId = $AllDataStore | Where-Object DataStoreName -eq $DataStoreName | 
                    Select-Object -ExpandProperty DataStoreId
                }
                catch {
                    # Don't exit, continue with other restores in the pipeline
                    Write-Error $_.Exception.Message
                    continue
                }
            
                $Body = @{
                    'datastore_id'         = $DataStoreId
                    'virtual_machine_name' = $RestoreVmName
                } | ConvertTo-Json
                Write-Verbose $Body
            }
            
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
                $Count += 1
            }
            catch {
                Write-Warning "$($_.Exception.Message), restore failed for VM $RestoreVmName"
            }
        } #end for
    } # end process
    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Delete one or more HPE SimpliVity backups
.DESCRIPTION
    Deletes one or more backups hosted on HPE SimpliVity. Use Get-SVTbackup output to pass in the backup(s) 
    to delete or specify the Backup ID, if known.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). 
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to 
    identify the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    The UID of the backup(s) to delete
.EXAMPLE
    PS C:\> Get-SVTBackup -BackupName 2019-05-09T22:00:01-04:00 | Remove-SVTbackup

    Deletes the backups with the specified backup name.
.EXAMPLE
    PS C:\> Get-SVTBackup -VmName MyVm -Hour 3 | Remove-SVTbackup

    Delete any backup that is at least 3 hours old for the specified virtual machine
.EXAMPLE
    PS C:\> Get-SVTBackup | ? VmName -match "test" | Remove-SVTbackup

    Delete all backups for all virtual machines that have "test" in their name
.EXAMPLE
    PS C:\> Get-SVTbackup -CreatedBefore 01/01/2020 -Limit 3000 | Remove-SVTbackup

    This command will remove backups older than the specified date.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This cmdlet uses the /api/backups/delete REST API POST call which creates a task to delete the specified 
    backup. This call accepts multiple backup IDs, and efficiently removes multiple backups with a single task. 
    This also works for backups in remote clusters.

    There is another REST API DELETE call (/api/backups/<bkpId>) which only works locally (i.e. when 
    connected to an OVC where the backup resides), but this fails when trying to delete remote backups.
#>
function Remove-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $BackupList = @()
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $Uri = $global:SVTconnection.OVC + '/api/backups/delete'
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
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop 
        }
        catch {
            Write-Warning "$($_.Exception.Message), failed to remove backup with id $BkpId"
        }
        $Task
        $global:SVTtask = $Task
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Stops (cancels) a currently executing HPE SimpliVity backup
.DESCRIPTION
    Stops (cancels) a currently executing HPE SimpliVity backup

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). 
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Specify the Backup ID(s) for the backup(s) to cancel
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName '2019-05-12T01:00:00-04:00' | Stop-SVTBackup

    Cancels the backup or backups with the specified backup name.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Stop-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/cancel'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), failed to stop backup with id $BkpId"
            }
        }
    }

    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to 
    identify the backups you want to target and then pass the output to this command.
.PARAMETER DestinationName
    Specify the destination SimpliVity Cluster name or external store name. If a cluster exists with the
    same name as an external store, the cluster wins.
.PARAMETER BackupId
    Specify the Backup ID(s) to copy. Use the output from an appropriate Get-SVTbackup command to provide
    one or more Backup ID's to copy. 
.EXAMPLE
    PS C:\> Get-SVTbackup -VmName Server2016-01 | Copy-SVTbackup -DestinationName Cluster02

    Copy the last 24 hours of backups for the specified VM to the specified SimpliVity cluster
.EXAMPLE
    PS C:\> Get-SVTbackup -Hour 2 | Copy-SVTbackup Cluster02

    Copy the last two hours of all backups to the specified cluster
.EXAMPLE
    PS C:\> Get-SVTbackup -Name 'BeforeSQLupgrade' | Copy-SVTbackup -DestinationName StoreOnce-Data02

    Copy backups with the specified name to the specified external store.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Copy-SVTbackup.md
#>
function Copy-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DestinationName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        try {
            $Destination = Get-SVTbackupDestination -Name $DestinationName -ErrorAction Stop

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
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/copy'
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), copy failed for backup with id $BkpId"
            }
        }
    }
    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Locks HPE SimpliVity backups to prevent them from expiring
.DESCRIPTION
    Locks HPE SimpliVity backups to prevent them from expiring

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name).
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify 
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Lock the backup(s) with the specified backup ID(s)
.EXAMPLE
    PS C:\> Get-SVTBackup -BackupName 2019-05-09T22:00:01-04:00 | Lock-SVTbackup
    PS C:\> Get-SVTtask

    Locks the backup(s) with the specified name. Use Get-SVTtask to track the progress of the task(s).
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Lock-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/lock'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), failed to lock backup with id $BkpId"
            }
            
        }
    }
    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Rename existing HPE SimpliVity backup(s)
.DESCRIPTION
    Rename existing HPE SimpliVity backup(s).

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). 
    This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify 
    the backups you want to target and then pass the output to this command.
.PARAMETER BackupName
    The new backup name. Must be a new unique name. The command fails if there are existing backups with 
    this name.
.PARAMETER BackupId
    The backup Ids of the backups to be renamed
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName "Pre-SQL update"
    PS C:\> Get-SVTbackup -BackupName 2019-05-11T09:30:00-04:00 | Rename-SVTBackup "Pre-SQL update"

    The first command confirms the backup name is not in use. The second command renames the specified backup(s).
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Rename-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [Alias('NewName')]
        [System.String]$BackupName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/rename'

            $Body = @{ 'backup_name' = $BackupName } | ConvertTo-Json
            Write-Verbose $Body

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), rename failed for backup $BkpId"
            }
        }
    }
    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Set the retention of existing HPE SimpliVity backups
.DESCRIPTION
    Change the retention on existing SimpliVity backup.

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same 
    name). This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup 
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
    PS C:\> Get-Backup -BackupName 2019-05-09T22:00:01-04:00 | Set-SVTbackupRetention -RetentionDay 21

    Gets the backups with the specified name and then sets the retention to 21 days.
.EXAMPLE
    PS C:\> Get-Backup -VmName Server2016-04 -Limit 1 | Set-SVTbackupRetention -RetentionHour 12

    Get the latest backup of the specified virtual machine and then sets the retention to 12 hours.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    OMNI-53536: Setting the retention time to a time that causes backups to be deleted fails
#>
function Set-SVTbackupRetention {
    [CmdletBinding(DefaultParameterSetName = 'ByDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByDay')]
        [System.Int32]$RetentionDay,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHour')]
        [System.Int32]$RetentionHour,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        $Uri = $global:SVTconnection.OVC + '/api/backups/set_retention'
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
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop

            # If the attempted retention date is in the past, the list of backup objects is returned.
            if ($Task.Backups) {
                throw "You cannot set a retention date that would immediately expire the target backup(s)"
            }
            else {
                $Task
                $global:SVTtask = $Task
                $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    name). This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup 
    to identify the backups you want to target and then pass the output to this command.
.PARAMETER BackupId
    Use Get-SVTbackup to output the required VMs as input for this command
.EXAMPLE
    PS C:\> Get-SVTbackup -VmName VM01 | Update-SVTbackupUniqueSize

    Starts a task to calculate the unique size of the specified backup(s)
.EXAMPLE
    PS:\> Get-SVTbackup -Date 26/04/2020 | Update-SVTbackupUniqueSize

    Starts a task per backup object to calculate the unique size of backups with the specified creation date.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command only updates the backups in the local cluster. Login to an OVC in a remote cluster to 
    update the backups there. The UniqueSizeDate property is updated on the backup object(s) when you run 
    this command
#>
function Update-SVTbackupUniqueSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/calculate_unique_size'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            [array]$AllTask += $Task
            $Task
        }
    }

    end {
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Display the virtual disk, partition and file information from a SimpliVity backup
.DESCRIPTION
    Displays the backed up files inside a SimpliVity backup. Different output is produced, depending on the 
    parameters provided. BackupId is a mandatory parameter and can be passed in from Get-SVTbackup.

    If no optional parameters are provided, or if VirtualDisk is not specified, the virtual disks contained 
    in the backup are shown. If a virtual disk name is provided, the partitions within the specified virtual 
    disk are shown. If the virtual disk and partition are provided, the files in the root path for the partition 
    are shown. If all three optional parameters are provided, the specified backed up files are shown.

    Notes:
    1. This command only works on backups from guests running Microsoft Windows. Backed up virtual disks and 
       partitions only can be displayed with backups of Linux guests.
    2. This command only works with native SimpliVity backups. (Backups on StoreOnce appliances do not work)
    3. Virtual disk names and folder paths are case sensitive
.PARAMETER BackupId
    The Backup Id for the desired backup. Use Get-SVTbackup to output the required backup as input for 
    this command
.PARAMETER VirtualDisk
    The virtual disk name contained within the backup, including file suffix (".vmdk")
.PARAMETER PartitionNumber
    The partition number within the specified virtual disk
.PARAMETER FilePath
    The folder path for the backed up files
.EXAMPLE
    PS C:\> $Backup = Get-SVTbackup -VmName Server2016-01 -Limit 1
    PS C:\> $Backup | Get-SVTfile

    The first command identifies the most recent backup of the specified VM.
    The second command displays the virtual disks contained within the backup
.EXAMPLE
    PS C:\> $Backup = Get-SVTbackup -VmName Server2016-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SVTfile -VirtualDisk Server2016-01.vmdk

    The first command identifies the most recent backup of the specified VM taken on a specific date. 
    The second command displays the partitions within the specified virtual disk. Virtual disk names are 
    case sensitive
.EXAMPLE 
    PS C:\> Get-SVTfile -BackupId 5f5f7f06...0b509609c8fb -VirtualDisk Server2016-01.vmdk -PartitionNumber 4

    Shows the contents of the root folder on the specified partition inside the specified backup
.EXAMPLE
    PS C:\> $Backup = Get-SVTbackup -VmName Server2016-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SVTfile Server2016-01.vmdk 4

    Shows the backed up files at the root of the specified partition, using positional parameters
.EXAMPLE
    PS C:\> $Backup = Get-SVTbackup -VmName Server2016-02 -Date 26/04/2020 -Limit 1
    PS C:\> $Backup | Get-SVTfile Server2016-01.vmdk 4 /Users/Administrator/Documents

    Shows the specified backed up files within the specified partition, using positional parameters. File 
    names are case sensitive.
.EXAMPLE
    PS C:\> $Backup = '5f5f7f06-a485-42eb-b4c0-0b509609c8fb' # This is a valid Backup ID
    PS C:\> $Backup | Get-SVTfile -VirtualDisk Server2016-01_1.vmdk -PartitionNumber 2 -FilePath '/Log Files'

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
#>
function Get-SVTfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
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
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/virtual_disk_partition_files' +
                '?virtual_disk=' + $VirtualDisk + '&partition_number=' + $PartitionNumber +
                '&file_path=' + $Folder
                try {
                    $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
                            LastModified         = ConvertFrom-SVTutc -Date $_.last_modified
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
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/virtual_disk_partitions' +
                '?virtual_disk=' + $VirtualDisk
                try {
                    $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/virtual_disks'
                try {
                    $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
    4. This command relies on the input from Get-SVTfile to pass in a valid backup file list to restore
    5. Whilst it is possible to use Get-SVTfile to list files in multiple backups, this command will only 
       restore files from the first backup passed in. Files in subsequent backups are ignored, because only one 
       DVD drive can be mounted on the target virtual machine.
    6. Folder size matters. The restore will fail if file sizes exceed a DVD capacity. When restoring a large
       amount of data, it might be faster to restore the entire virtual machine and recover the required files 
       from the restored virtual disk.
    7. File level restores are resticted to nine virtual disks per virtual controller. When viewing the virtual
       disks with Get-SVTfile, you will only see the first nine disks if they are all attached to the same 
       virtual controller. In this case, you must restore the entire VM and restore the required files from the
       restored virtual disk (VMDK) files.
.PARAMETER VmName
    The target virtual machine. Ensure the DVD drive is disconnected
.PARAMETER RestorePath
    An array containing the backup ID and the full path of the folder to restore. This consists of the virtual 
    disk name, partition and folder name. The Get-SVTfile provides this parameter in the expected format, 
    e.g. "/Server2016-01.vmdk/4/Users/Administrator/Documents".

.EXAMPLE
    PS C:\> $Backup = Get-SVTbackup -VmName Server2016-01 -Name 2020-04-26T18:00:00+10:10
    PS C:\> $File = $Backup | Get-SVTfile Server2016-01.vmdk 4 '/Log Files'
    PS C:\> $File | Restore-SVTfile -VmName Server2016-02

    The first command identifies the desired backup. 
    The second command enumerates the files from the specified virtual disk, partition and file path in the backup
    The third command restores those files to an ISO and then connects this to the specified virtual machine.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Restore-SVTfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$VmName,

        [Parameter(Mandatory = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.Object]$RestorePath
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $PrevBackupId = $null
        $FileList = @()
        
        try {
            $VMid = Get-SVTvm -VmName $VmName -ErrorAction Stop | Select-Object -ExpandProperty VMid
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
                Write-Warning 'Restore-SVTfile will only restore files from the first backup passed in'
            }
        }
    }

    end {
        $Uri = $global:SVTconnection.OVC + '/api/backups/' + $Restore.BackupId + '/restore_files' 
        $Body = @{
            'virtual_machine_id' = $VMid
            'paths'              = $FileList
        } | ConvertTo-Json
        Write-Verbose $Body
        
        try {
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        [array]$AllTask += $Task
        $Task
        
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

#endregion Backup

#region Datastore

<#
.SYNOPSIS
    Display HPE SimpliVity datastore information
.DESCRIPTION
    Shows datastore information from the SimpliVity Federation
.PARAMETER DataStoreName
    Show information for the specified datastore only
.EXAMPLE
    PS C:\> Get-SVTdatastore

    Shows all datastores in the Federation
.EXAMPLE
    PS C:\> Get-SVTdatastore -Name DS01 | Export-CSV Datastore.csv

    Writes the specified datastore information into a CSV file
.EXAMPLE
    PS C:\> Get-SVTdatastore DS01,DS02,DS03 | Select-Object Name, SizeGB, Policy

    Shows the specified properties for the HPE SimpliVity datastores
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.DataStore
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastore.md
#>
function Get-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$DatastoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/datastores?show_optional_fields=true&case=insensitive'

    if ($PSBoundParameters.ContainsKey('DatastoreName')) {
        $Uri += "&name=$($DatastoreName -join ',')"
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('DatastoreName') -and -not $Response.datastores.name) {
        throw "Specified datastore(s) $DatastoreName not found"
    }

    $Response.datastores | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.DataStore'
            ClusterGroupIds          = $_.cluster_group_ids
            PolicyId                 = $_.policy_id
            MountDirectory           = $_.mount_directory
            CreateDate               = ConvertFrom-SVTutc -Date $_.created_at
            PolicyName               = $_.policy_name
            ClusterName              = $_.omnistack_cluster_name
            Shares                   = $_.shares
            Deleted                  = $_.deleted
            HyperVisorId             = $_.hypervisor_object_id
            SizeGB                   = '{0:n0}' -f ($_.size / 1gb)
            DataStoreName            = $_.name
            DataCenterId             = $_.compute_cluster_parent_hypervisor_object_id
            DataCenterName           = $_.compute_cluster_parent_name
            HypervisorType           = $_.hypervisor_type
            DataStoreId              = $_.id
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
.PARAMETER DataStoreName
    Specify the name of the new datastore
.PARAMETER ClusterName
    Specify the cluster of the new datastore
.PARAMETER PolicyName
    Specify the existing backup policy to assign to the new datastore
.PARAMETER SizeGB
    Specify the size of the new datastore in GB
.EXAMPLE
    PS C:\> New-SVTdatastore -DatastoreName ds01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 102400

    Creates a new 100TB datastore called ds01 on Cluster1 and assigns the pre-existing Daily backup policy to it
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function New-SVTdatastore {
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
        [System.int32]$SizeGB
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/datastores/'

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
        Select-Object -ExpandProperty ClusterId
        
        $PolicyID = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    $Body = @{
        'name'                 = $DataStoreName
        'omnistack_cluster_id' = $ClusterId
        'policy_id'            = $PolicyId
        'size'                 = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Remove an HPE SimpliVity datastore
.DESCRIPTION
    Removes the specified SimpliVity datastore. The datastore cannot be in use by any virtual machines.
.PARAMETER DatastoreName
    Specify the datastore to delete
.EXAMPLE
    PS C:\> Remove-SVTdatastore -Datastore DStemp
    PS C:\> Get-SVTtask

    Remove the datastore and monitor the task to ensure it completes successfully.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Remove-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
        Select-Object -ExpandProperty DatastoreId
        
        $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw $($_.Exception.Message)
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Resize a HPE SimpliVity Datastore
.DESCRIPTION
    Resizes a specified datastore to the specified size in GB. The datastore size can be
    between 1GB and 1,048,576 GB (1,024TB).
.EXAMPLE
    PS C:\> Resize-SVTdatastore -DatastoreName ds01 -SizeGB 1024

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
#>
function Resize-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 1048576)] # Max is 1024TB (as per GUI)
        [System.Int32]$SizeGB
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/resize'
        $Body = @{ 'size' = $SizeGB * 1Gb } | ConvertTo-Json # Size must be in bytes
        Write-Verbose $Body
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Set-SVTdatastorePolicy -DatastoreName ds01 -PolicyName Weekly

    Assigns a new backup policy to the specified datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Set-SVTdatastorePolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/set_policy'

        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
        Select-Object -ExpandProperty PolicyId -Unique

        $Body = @{ 'policy_id' = $PolicyId } | ConvertTo-Json
        Write-Verbose $Body
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Publish-SVTdatastore -DatastoreName DS01 -ComputeNodeName ESXi03

    The specified compute node is given access to the datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
#>
function Publish-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
        Select-Object -ExpandProperty DatastoreId

        $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/share'
        $Body = @{ 'host_name' = $ComputeNodeName } | ConvertTo-Json
        Write-Verbose $Body
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Unpublish-SVTdatastore -DatastoreName DS01 -ComputeNodeName ESXi01

    The specified compute node will no longer have access to the datastore
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
#>
function Unpublish-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ComputeNodeName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }

    $Body = @{ 'host_name' = $ComputeNodeName } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
        Select-Object -ExpandProperty DatastoreId
        
        $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/unshare'
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask # Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Displays the compute hosts (standard ESXi hosts) that have access to the specified datastore(s)
.DESCRIPTION
    Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS
.PARAMETER DatastoreName
    Specify the datastore to display information for
.EXAMPLE
    PS C:\> Get-SVTdatastoreComputeNode -DatastoreName DS01

    Display the compute nodes that have NFS access to the specified datastore
.EXAMPLE
    PS C:\> Get-SVTdatastoreComputeNode

    Displays all datastores in the Federation and the compute nodes that have NFS access to them
.INPUTS
    system.string
    HPE.SimpliVity.Datastore
.OUTPUTS
    HPE.SimpliVity.ComputeNode
.NOTES
    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
#>
function Get-SVTdatastoreComputeNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$DatastoreName = (Get-SVTdatastore | Select-Object -ExpandProperty DatastoreName)
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
        }
    }

    process {
        foreach ($ThisDatastore in $DatastoreName) {
            try {
                $DatastoreId = Get-SVTdatastore -DatastoreName $ThisDatastore -ErrorAction Stop | 
                Select-Object -ExpandProperty DatastoreId

                $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/standard_hosts'
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.standard_hosts | ForEach-Object {
                [PSCustomObject]@{
                    PSTypeName         = 'HPE.SimpliVity.ComputeNode'
                    DataStoreName      = $ThisDatastore
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
    Displays information on the available external datastores configurated in HPE SimpliVity
.DESCRIPTION
    Displays external stores that have been registered. Upon creation, external datastores are associated
    with a specific SimpliVity cluster, but are subsequently available to all clusters in the cluster group
    to which the specified cluster is a member.

    External Stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped 
    backups to HPE SimpliVity.
.PARAMETER ExternalStoreName
    Specify the external datastore to display information
.EXAMPLE
    PS C:\> Get-SVTexternalStore StoreOnce-Data01,StoreOnce-Data02,StoreOnce-Data03
    PS C:\> Get-SVTexternalStore -Name StoreOnce-Data01

    Display information about the specified external datastore(s)
.EXAMPLE
    PS C:\> Get-SVTexternalStore

    Displays all external datastores in the Federation
.INPUTS
    system.string
.OUTPUTS
    HPE.SimpliVity.Externalstore
.NOTES
    This command works with HPE SimpliVity 4.0.0 and above
#>
function Get-SVTexternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$ExternalStoreName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/external_stores?case=insensitive'
    if ($PSBoundParameters.ContainsKey('ExternalstoreName')) {
        $Uri += "&name=$($ExternalstoreName -join ',')"
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ExternalStoreName') -and -not $Response.external_stores.name) {
        throw "Specified external datastore(s) $ExternalStoreName not found"
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
    PS C:\> New-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SVTcluster
        -ManagementIP 192.168.10.202 -Username SVT_service -Userpass Password123

    Registers a new external datastore called StoreOnce-Data03 with the specified HPE SimpliVity Cluster,
    using preconfigured credentials. 
.INPUTS
    system.string
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command works with HPE SimpliVity 4.0.0 and above
#>
function New-SVTexternalStore {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
    }
    
    $Uri = $global:SVTconnection.OVC + '/api/external_stores'

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
        Select-Object -ExpandProperty ClusterId
    }
    catch {
        $_.Exception.Message
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
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used

}

<#
.SYNOPSIS
    Unregisters (removes) an external datastore from the specified HPE SimpliVity cluster
.DESCRIPTION
    Unregisters an external datastore. Removes the external store as a backup destination for the cluster.
    Backups remain on the external store, but they can no longer be managed by HPE SimpliVity.

    External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped 
    backups to HPE SimpliVity. Once unregistered, the Catalyst store remains on the StoreOnce appliance but
    is inaccessible to HPE SimpliVity.
.PARAMETER ExternalStoreName
    External datastore name. This is the pre-existing Catalyst store name on HPE StoreOnce
.PARAMETER ClusterName
    The HPE SimpliVity cluster name to associate this external store. Once created, the external store is
    available to all clusters in the cluster group
.EXAMPLE
    PS C:\> Remove-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SVTcluster

    Unregisters (removes) the external datastore called StoreOnce-Data03 from the specified 
    HPE SimpliVity Cluster
.INPUTS
    system.string
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command works with HPE SimpliVity 4.0.1 and above
#>
function Remove-SVTexternalStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$ExternalStoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.15+json'
    }
    
    $Uri = $global:SVTconnection.OVC + '/api/external_stores/unregister'

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
        Select-Object -ExpandProperty ClusterId

        $Body = @{
            'name'                 = $ExternalStoreName
            'omnistack_cluster_id' = $ClusterID
        } | ConvertTo-Json
        Write-Verbose $Body
        
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Set-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ManagementIP 192.168.10.202 
        -Username SVT_service -Userpass Password123

    Resets the external datastore credentials and management IP address
.INPUTS
    system.string
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command works with HPE SimpliVity 4.0.1 and above
#>
function Set-SVTexternalStore {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.15+json'
    }
    
    $Uri = $global:SVTconnection.OVC + '/api/external_stores/update_credentials'

    $Body = @{
        'management_ip' = $ManagementIP
        'name'          = $ExternalStoreName
        'password'      = $Userpass
        'username'      = $Username
    } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    Show hosts from the specified SimpliVity cluster only
.EXAMPLE
    PS C:\> Get-SVThost

    Shows all hosts in the Federation
.EXAMPLE
    PS C:\> Get-SVThost -Name Host01
    PS C:\> Get-SVThost Host01,Host02

    Shows the specified host(s)
.EXAMPLE
    PS C:\> Get-SVThost -ClusterName MyCluster

    Shows hosts in specified HPE SimpliVity cluster(s)
.EXAMPLE
    PS C:\> Get-SVTHost | Where-Object DataCenter -eq MyDC | Format-List *

    Shows all properties for all hosts in the specified Datacenter
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Host
.NOTES
#>
function Get-SVThost {
    [CmdletBinding(DefaultParameterSetName = 'ByHostName')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByHostName')]
        [Alias('Name')]
        [System.String[]]$HostName,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [System.String[]]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/hosts?show_optional_fields=true&case=insensitive'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&compute_cluster_name=$($ClusterName -join ',')"
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ClusterName') -and -not $Response.hosts.name) {
        throw "Specified cluster(s) $ClusterName not found"
    }

    if ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $FullHostName = Resolve-SVTFullHostName $HostName $Response.hosts.name -ErrorAction Stop
            foreach ($Thishost in $FullHostName) {
                [array]$MatchedHost += $Response.hosts | ForEach-Object { 
                    $_ | Where-Object { $_.name -eq $Thishost }
                }
            }
            $Response = @{ hosts = $MatchedHost }  # repack the object with just the host objects we want
        }
        catch {
            throw $_.Exception.Message
        }
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
            StoreageMTU               = $_.storage_mtu
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
            Date                      = ConvertFrom-SVTutc -Date $_.date
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
    PS C:\> Get-SVThardware -HostName Host01 | Select-Object -ExpandProperty LogicalDrives

    Enumerates all of the logical drives from the specified host
.EXAMPLE
    PS C:\> (Get-SVThardware Host01).RaidCard

    Enumerate all of the RAID cards from the specified host
.EXAMPLE
    PC C:\> Get-SVThardware Host1,Host2,Host3

    Shows hardware information for all hosts in the specified list
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Hardware
.NOTES
#>
function Get-SVThardware {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
        }

        $Allhost = Get-SVThost
        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SVTFullHostName $HostName $Allhost.HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $Allhost | Select-Object -ExpandProperty HostName
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            # Get the HostId for this host
            $HostId = ($Allhost | Where-Object HostName -eq $Thishost).HostId

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/hardware'

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            $Response.host | ForEach-Object {
                [pscustomobject]@{
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
            } #end foreach-object
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
    PS C:\> Get-SVTdisk

    Shows physical disk information for all SimpliVity hosts in the federation.
.EXAMPLE
    PS C:\> Get-SVTdisk -HostName Host01

    Shows physical disk information for the specified SimpliVity host.
.EXAMPLE
    PS C:\> Get-SVTdisk -HostName Host01 | Select-Object -First 1 | Format-List

    Show all of the available information about the first disk on the specified host.
.EXAMPLE
    PC C:\> Get-SVThost -Cluster PROD | Get-SVTdisk

    Shows physical disk information for all hosts in the specified cluster.
.EXAMPLE
    PC C:\> Get-SVThost Host1,Host2,Host3

    Shows physical disk information for all hosts in the specified list
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Hardware
.NOTES
#>
function Get-SVTdisk {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $LocalCulture = Get-Culture #[System.Threading.Thread]::CurrentThread.CurrentCulture

        $Hardware = Get-SVThardware
        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SVTFullHostName $HostName $Hardware.HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $Hardware | Select-Object -ExpandProperty HostName
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            $HostHardware = $Hardware | Where-Object HostName -eq $Thishost
            
            # We MUST sort by slot number to ensure SSDs are at the top to properly support 380 H
            # This command removes duplicates - all models have at least two logical disks where physical
            # disks would otherwise appear twice in the collection.
            $Disk = $HostHardware.logicaldrives.drive_sets.physical_drives | 
            Sort-Object { [system.Int32]($_.Slot -replace '(\d+).*', '$1') } |
            Get-Unique -AsString
            
            # Check capacity of first disk in collection (works ok all most models - 380 H included, for now)
            $DiskCapacity = [int][math]::Ceiling(($Disk | Select-Object -First 1).capacity / 1TB)
            $DiskCount = ($Disk | Measure-Object).Count
            
            $SVTmodel = Get-SVTmodel | Where-Object {
                $HostHardware.Model -match $_.Model -and
                $DiskCount -eq $_.DiskCount -and
                $DiskCapacity -eq $_.DiskCapacity
            }

            if ($SVTmodel) {
                $Kit = $SVTmodel.StorageKit
            }
            else {
                $Kit = 'Unknown Storage Kit'
            }

            $Disk | ForEach-Object {
                [pscustomobject]@{
                    PSTypeName      = 'HPE.SimpliVity.Disk'
                    SerialNumber    = $_.serial_number
                    Manufacturer    = $_.manufacturer
                    ModelNumber     = $_.model_number
                    Firmware        = $_.firmware_revision
                    Status          = $_.status
                    Health          = $_.health
                    Enclosure       = [System.Int32]$_.enclosure
                    Slot            = [System.Int32]$_.slot
                    CapacityTB      = [single]::Parse('{0:n2}' -f ($_.capacity / 1000000000000), $LocalCulture)
                    WWN             = $_.wwn
                    PercentRebuilt  = [System.Int32]$_.percent_rebuilt
                    AddtionalStatus = $_.additional_status
                    MediaType       = $_.media_type
                    DrivePosition   = $_.drive_position
                    RemainingLife   = $_.life_remaining
                    HostStorageKit  = $Kit
                    HostName        = $ThisHost
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
    PS C:\> Get-SVTcapacity MyHost

    Shows capacity information for the specified host for the last 24 hours
.EXAMPLE
    PS C:\> Get-SVTcapacity -HostName MyHost -Hour 1 -Resolution MINUTE

    Shows capacity information for the specified host showing every minute for the last hour
.EXAMPLE
    PS C:\> Get-SVTcapacity -Chart

    Creates a chart for each host in the SimpliVity federation showing the latest (24 hours) capacity details
.EXAMPLE
    PC C:\> Get-SVTcapacity Host1,Host2,Host3

    Shows capacity information for all hosts in the specified list
.INPUTS
    system.string
    HPESimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Capacity
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTcapacity.md
#>
function Get-SVTcapacity {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [string[]]$HostName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$OffsetHour = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.Int32]$Hour = 24,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'HOUR',

        [Parameter(Mandatory = $false)]
        [switch]$Chart
    )

    begin {
        #$VerbosePreference = 'Continue'

        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
        }
        $Range = $Hour * 3600
        $Offset = $OffsetHour * 3600

        $Allhost = Get-SVThost
        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SVTFullHostName $HostName $Allhost.HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $Allhost | Select-Object -ExpandProperty HostName
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
            $HostId = ($Allhost | Where-Object HostName -eq $Thishost).HostId

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/capacity?time_offset=' +
            $Offset + '&range=' + $Range + '&resolution=' + $Resolution
            
            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = ConvertFrom-SVTutc -Date $_.date
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
                    PStypeName = 'HPE.SimpliVity.Capacity'
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
            Get-SVTcapacityChart -Capacity $ChartObject
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
    will fail. You can specify the force command, but we aware that this could cause data loss.
.PARAMETER HostName
    Specify the node to remove.
.PARAMETER Force
    Forces removal of the node from the HPE SimpliVity federation. THIS CAN CAUSE DATA LOSS. If there is one 
    node left in the cluster, this parameter must be specified (removes HA compliance for any VMs in the 
    affected cluster.)
.EXAMPLE
    PS C:\> Remove-SVThost -HostName Host01

    Removes the node from the federation providing there are no VMs running and providing the 
    node is HA-compliant.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Remove-SVThost {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$HostName,

        [switch]$Force
    )

    # V4.0.0 states this is now application/vnd.simplivity.v1.14+json, 
    # but there don't appear to be any new features
    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    try {
        $HostId = Get-SVThost -HostName $HostName -ErrorAction Stop | Select-Object -ExpandProperty HostId
        $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/remove_from_federation'
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

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Shutdown a HPE Omnistack Virtual Controller
.DESCRIPTION
    Ideally, you should only run this command when all the VMs in the cluster
    have been shutdown, or if you intend to leave virtual controllers running in the cluster.

    This RESTAPI call only works if executed on the local host to the virtual controller. So this command
    connects to the virtual controller on the specified host to shut it down.

    Note: Once the shutdown is executed on the specified host, this command will reconnect to another 
    operational virtual controller in the Federation, using the same credentials, if there is one.
.PARAMETER HostName
    Specify the host name running the OmniStack virtual controller to shutdown
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName <Name of SimpliVity host>

    if not the last operational virtual controller, this command waits for the affected VMs to be HA 
    compliant. If it is the last virtual controller, the shutdown does not wait for HA compliance.

    You will be prompted before the shutdown. If this is the last virtual controller, ensure all virtual 
    machines are powered off, otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName Host01 -Confirm:$false

    Shutdown the specified virtual controller without confirmation. If this is the last virtual controller, 
    ensure all virtual machines are powered off, otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName Host01 -Whatif -Verbose

    Reports on the shutdown operation, including connecting to the virtual controller, without actually 
    performing the shutdown.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
#>
function Start-SVTshutdown {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHostName')]
        [System.String]$HostName
    )

    $VerbosePreference = 'Continue'
    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    try {
        $Allhost = Get-SVThost -ErrorAction Stop
        $ThisHost = $Allhost | Where-Object HostName -eq $HostName
        
        $NextHost = $Allhost | Where-Object { $_.HostName -ne $HostName -and $_.State -eq 'ALIVE' } | 
        Select-Object -First 1 # so we can reconnect afterwards
        $ThisCluster = $ThisHost | Select-Object -First 1 -ExpandProperty Clustername

        $LiveHost = $Allhost | Where-Object { $_.ClusterName -eq $ThisCluster -and $_.State -eq 'ALIVE' } | 
        Measure-Object | Select-Object -ExpandProperty Count

        $Allhost | Where-Object ClusterName -eq $ThisCluster | ForEach-Object {
            Write-Verbose "Current state of host $($_.HostName) in cluster $ThisCluster is $($_.State)" 
        }
    }
    catch {
        throw $_.Exception.Message
    }

    # Exit if the virtual controller is already off
    if ($ThisHost.State -ne 'ALIVE') {
        $ThisHost.State
        throw "The HPE Omnistack Virtual Controller on $($ThisHost.HostName) is not running"
    }

    if ($NextHost) {
        $Message = "This command will reconnect to $($NextHost.HostName) following the shutdown of the " +
        "virtual controller on $($ThisHost.HostName)"
        Write-Verbose $Message
    }
    else {
        $Message = 'This is the last operational HPE Omnistack Virtual Controller in the federation, ' +
        'reconnect not possible'
        Write-Verbose $Message
    }

    # Connect to the target virtual controller, using the existing credentials saved to $SVTconnection
    try {
        Write-Verbose "Connecting to $($ThisHost.VirtualControllerName) on host $($ThisHost.HostName)..."
        Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential -ErrorAction Stop | Out-Null
        Write-Verbose "Successfully connected to $($ThisHost.VirtualControllerName) on host $($ThisHost.HostName)"
    }
    catch {
        throw $_.Exception.Message
    }

    # Confirm if this is the last running virtual controller in this cluster
    Write-Verbose "$LiveHost operational HPE Omnistack virtual controller(s) in the $ThisCluster cluster"
    if ($LiveHost -lt 2) {
        Write-Warning "This is the last Omnistack virtual controller running in the $ThisCluster cluster"
        $Message = 'Using this command with confirm turned off could result in loss of data if you have ' +
        'not already powered off all virtual machines'
        Write-Warning $Message
    }

    # Only execute the command if confirmed. Using -Whatif will report only
    if ($PSCmdlet.ShouldProcess("$($ThisHost.HostName)", "Shutdown virtual controller in cluster $ThisCluster")) {
        try {
            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + '/shutdown_virtual_controller'
            $Body = @{ 'ha_wait' = $true } | ConvertTo-Json
            Write-Verbose $Body
            $null = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        if ($LiveHost -le 1) {
            Write-Verbose 'Sleeping 10 seconds before issuing final shutdown...'
            Start-Sleep -Seconds 10

            try {
                # Instruct the shutdown task running on the last virtual controller in the cluster not to 
                # wait for HA compliance
                $Body = @{'ha_wait' = $false } | ConvertTo-Json
                Write-Verbose $Body
                $null = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
                Connect-SVT -OVC $NextHost.ManagementIP -Credential $SVTconnection.Credential `
                    -ErrorAction Stop | Out-Null
                
                $Message = "Successfully reconnected to $($NextHost.VirtualControllerName) " +
                "on $($NextHost.HostName)"
                Write-Verbose $Message

                $OVCrunning = $true
                $Message = 'Wait to allow the storage IP to failover to an operational virtual controller. ' + 
                'This may take a long time if the host is running virtual machines.'
                Write-Verbose $Message
                do {
                    $Message = 'Waiting 30 seconds, do not issue additional shutdown commands until this ' +
                    'operation completes...'
                    Write-verbose $Message
                    Start-Sleep -Seconds 30
                    
                    $OVCstate = Get-SVThost -HostName $($ThisHost.HostName) -ErrorAction Stop | 
                    Select-Object -ExpandProperty State

                    if ($OVCstate -eq 'FAULTY') {
                        $OVCrunning = $false
                    }
                } while ($OVCrunning)

                Write-Output "Successfully shutdown the virtual controller on $($ThisHost.HostName)"
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $Message = 'This was the last operational HPE Omnistack Virtual Controller in the Federation, ' +
            'reconnect not possible'
            Write-Verbose $Message
        }
    } #endif should process
}

<#
.SYNOPSIS
    Get the shutdown status of one or more Omnistack Virtual Controllers
.DESCRIPTION
    This RESTAPI call only works if executed on the local host to the OVC. So this cmdlet
    iterates through the specified hosts and connects to each specified host to sequentially get the status.

    This RESTAPI call only works if status is 'None' (i.e. the OVC is responsive), which kind of renders 
    the REST API a bit useless. However, this cmdlet is still useful to identify the unresponsive (i.e shut 
    down or shutting down) OVC(s).

    Note, because we're connecting to each OVC, the connection token will point to the last OVC we 
    successfully connect to. You may want to reconnect to your preferred OVC again using Connect-SVT.
.PARAMETER HostName
    Show shutdown status for the specified host only
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

    HostName is passed in them the pipeline by value. Same as:
    Get-SVTshutdownStatus -HostName '10.10.57.59','10.10.57.61'
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
#>
function Get-SVTshutdownStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.1+json'
        }

        $Allhost = Get-SVThost
        if ($PSBoundParameters.ContainsKey('HostName')) {
            try {
                $HostName = Resolve-SVTFullHostName $HostName $Allhost.HostName -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            $HostName = $Allhost | Select-Object -ExpandProperty HostName
        }
    }

    process {
        foreach ($ThisHostName in $HostName) {
            $ThisHost = $Allhost | Where-Object HostName -eq $ThisHostName

            try {
                Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential -ErrorAction Stop | 
                Out-Null
                
                Write-Verbose $SVTconnection
            }
            catch {
                $Message = "The virtual controller $($ThisHost.ManagementName) on " +
                "host $ThisHostName is not responding"
                Write-Error $Message
                continue
            }

            try {
                $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + 
                '/virtual_controller_shutdown_status'
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
    Cancel the previous shutdown command for one or more OmniStack Virtual Controllers
.DESCRIPTION
    Cancels a previously executed shutdown request for one or more OmniStack Virtual Controllers

    This RESTAPI call only works if executed on the local OVC. So this cmdlet iterates through the specified 
    hosts and connects to each specified host to sequentially shutdown the local OVC.

    Note, once executed, you'll need to reconnect back to a surviving OVC, using Connect-SVT to continue
    using the HPE SimpliVity cmdlets.
.PARAMETER HostName
    Specify the HostName running the OmniStack virtual controller to cancel the shutdown task on
.EXAMPLE
    PS C:\> Stop-SVTshutdown -HostName Host01
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
#>
function Stop-SVTshutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/json'
        }

        # Get all the hosts in the Federation.
        # We will be cancelling shutdown for one or more OVC's; grab all host information before we start
        try {
            $Allhost = Get-SVThost -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($ThisHostName in $HostName) {
            # grab this host object from the collection
            $ThisHost = $Allhost | Where-Object HostName -eq $ThisHostName
            Write-Verbose $($ThisHost | Select-Object HostName, HostId)

            # Now connect to this host, using the existing credentials saved to global variable
            Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential | Out-Null
            Write-Verbose $SVTconnection

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + 
            '/cancel_virtual_controller_shutdown'

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
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
        } # end foreach host
    } # end process
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

    Shows information about all clusters in the Federation
.EXAMPLE
    PS C:\> Get-SVTcluster Prod01
    PS C:\> Get-SVTcluster -Name Prod01

    Shows information about the specified cluster
.EXAMPLE
    PS C:\> Get-SVTcluster cluster1,cluster2

    Shows information about the specified clusters
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Cluster
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTcluster.md
#>
function Get-SVTcluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters?show_optional_fields=true&case=insensitive'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&name=$($ClusterName -join ',')"
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('ClusterName') -and -not $Response.omnistack_clusters.name) {
        throw "Specified cluster(s) $ClusterName not found"
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
    PS C:\> Get-SVTthroughput

    Displays the throughput information for the first cluster in the Federation, (alphabetically,
    by name)
.EXAMPLE
    PS C:\> Get-SVTthroughput -Cluster Prod01

    Displays the throughput information for the specified cluster
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTthroughput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$ClusterName = (Get-SVTcluster | 
            Sort-Object ClusterName | Select-Object -ExpandProperty ClusterName -First 1),

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$Hour = 12,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.Int32]$OffsetHour = 0
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Range = $Hour * 3600
    $Offset = $OffsetHour * 3600

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
        Select-Object -ExpandProperty ClusterId

        $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/throughput'
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Uri = $Uri + "?time_offset=$Offset&range=$Range"
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.cluster_throughput | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName                       = 'HPE.SimpliVity.Throughput'
            Date                             = ConvertFrom-SVTutc -Date $_.date
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
            MinDate                          = ConvertFrom-SVTutc -Date $_.data.date_of_minimum
            MaxThroughput                    = '{0:n0}' -f $_.data.maximum_throughput
            MaxDate                          = ConvertFrom-SVTutc -Date $_.data.date_of_maximum
        }
    }
}

<#
.SYNOPSIS
    Displays the timezones that HPE SimpliVity supports
.DESCRIPTION
    Displays the timezones that HPE SimpliVity supports
.EXAMPLE
    PS C:\> Get-SVTtimezone

.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTtimezone {
    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/time_zone_list'

    try {
        Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
}

<#
.SYNOPSIS
    Sets the timezone on a HPE SimpliVity cluster
.DESCRIPTION
    Sets the timezone on a HPE SimpliVity cluster

    Use 'Get-SVTtimezone' to see a list of valid timezones
    Use 'Get-SVTcluster | Select-Object TimeZone' to see the currently set timezone
.PARAMETER ClusterName
    Specify the cluster whose timezone you'd like set
.PARAMETER TimeZone 
    Specify the valid timezone. Use Get-Timezone to see a list of valid timezones 
.EXAMPLE
    PS C:\> Set-SVTtimezone -Cluster PROD -Timezone 'Australia/Sydney'

    Sets the time zone for the specified cluster
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Set-SVTtimezone {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$TimeZone
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
        Select-Object -ExpandProperty ClusterId
        
        $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/set_time_zone'

        if ($TimeZone -in (Get-SVTtimezone)) {
            $Body = @{ 'time_zone' = $TimeZone } | ConvertTo-Json
            Write-Verbose $Body
        }
        else {
            throw "Specified timezone $Timezone is not valid. Use Get-SVTtimezone to show valid timezones"
        }
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Get-SVTclusterConnected -ClusterName Production

    Displays information about the clusters directly connected to the specified cluster
.EXAMPLE
    PS C:\> Get-SVTclusterConnected

    Displays information about the first cluster in the federation (by cluster name, alphabetically)
.INPUTS
    System.String
.OUTPUTS
    PSCustomObject
.NOTES
.LINK
    https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTclusterConnected.md
#>
function Get-SVTclusterConnected {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.String]$ClusterName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $AllCluster = Get-SVTcluster -ErrorAction Stop
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
        $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/connected_clusters'
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $Response.omnistack_clusters | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName             = 'HPE.SimpliVity.ConnectedCluster'
            Clusterid              = $_.id
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
            ConnectedClusters      = $_.connected_clusters
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
    PS C:\> Get-SVTpolicy

    Shows all policy rules for all backup policies
.EXAMPLE
    PS C:\> Get-SVTpolicy -PolicyName Silver, Gold

    Shows the rules from the specified backup policies
.EXAMPLE
    PS C:\> Get-SVTpolicy | Where RetentionDay -eq 7

    Show all policy rules that have a 7 day retention
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Policy
.NOTES
#>
function Get-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Name')]
        [System.String[]]$PolicyName,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Int32]$RuleNumber
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies?case=insensitive'
    if ($PSBoundParameters.ContainsKey('PolicyName')) {
        $PolicyList = $PolicyName -join ','
        $Uri += '&name=' + $PolicyList
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    } 

    if ($PSBoundParameters.ContainsKey('PolicyName') -and -not $Response.policies.Name) {
        throw "Specified policies(s) $PolicyList not found"
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
    policy, use New-SVTpolicyRule. 
    
    To assign the new backup policy, use Set-SVTdatastorePolicy to assign it to a datastore, or 
    Set-SVTvmPolicy to assign it to a virtual machine.
.PARAMETER PolicyName
    The new backup policy name to create
.EXAMPLE
    PS C:\> New-SVTpolicy -Policy Silver

    Creates a new blank backup policy. To create or replace rules for the new backup policy, 
    use New-SVTpolicyRule.
.EXAMPLE
    PS C:\> New-SVTpolicy Gold

    Creates a new blank backup policy. To create or replace rules for the new backup policy, 
    use New-SVTpolicyRule.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function New-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies/'
    $Body = @{ 'name' = $PolicyName } | ConvertTo-Json
    Write-Verbose $Body

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask # Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Create a new backup policy rule in a HPE SimpliVity backup policy
.DESCRIPTION
    Create backup policies within an existing HPE Simplivity backup policy. Optionally,
    You can replace all the existing policy rules with the new policy rule.

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
    If this switch is specified, ALL existing rules in the specified backup policy are removed and 
    replaced with this new rule.
.PARAMETER ImpactReportOnly
    Rather than create the policy rule, display a report showing the impact this change would make. The report 
    shows projected daily backup rates and new total retained backups given the frequency and retention settings
    for the specified backup policy.
.EXAMPLE
    PS C:\> New-SVTpolicyRule -PolicyName Silver -All -DestinationName cluster1 -ReplaceRules

    Replaces all existing backup policy rules with a new rule, backup every day to the specified cluster, 
    using the default start time (00:00), end time (00:00), Frequency (1440, or once per day), retention of 
    1 day and no application consistency.
.EXAMPLE
    PS C:\> New-SVTpolicyRule -PolicyName Bronze -Last -ExternalStoreName StoreOnce-Data02 -RetentionDay 365

    Backup VMs on the last day of the month, storing them on the specified external datastore and retaining the
    backup for one year.
    
    PS C:\> New-SVTpolicyRule -PolicyName Silver -Weekday Mon,Wed,Fri -DestinationName cluster01 -RetentionDay 7

    Adds a new rule to the specified policy to run backups on the specified weekdays and retain backup for a week.
.EXAMPLE
    PS C:\> New-SVTpolicyRule ShortTerm -RetentionHour 4 -FrequencyMin 60 -StartTime 09:00 -EndTime 17:00

    Add a new rule to a policy called ShortTerm, to backup once per hour during office hours and retain the
    backup for 4 hours. (Note: -RetentionHour takes precedence over -RetentionDay if both are specified)
.EXAMPLE
    PS C:\> New-SVTpolicyRule Silver -LastDay -DestinationName Prod -RetentionDay 30 -ConsistencyType VSS

    Add a new rule to the specified policy to run an application consistent backup on the last day 
    of each month, retaining it for 1 month.
.EXAMPLE
    PS C:\> New-SVTpolicyRule Silver -All -DestinationName Prod -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that creating this new policy rule would 
    make to the system. The report shows projected daily backup rates and total retained backup rates.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    PSCustomObject
.NOTES
#>
function New-SVTpolicyRule {
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
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if ($PSBoundParameters.ContainsKey('DestinationName')) {
        try {
            $Destination = Get-SVTbackupDestination -Name $DestinationName -ErrorAction Stop

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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/impact_report/create_rules'
        if ($PSBoundParameters.ContainsKey('ReplaceRules')) {
            $Uri += "?replace_all_rules=$true"
        }
        else {
            $Uri += "?replace_all_rules=$false"
        }

        try {
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SVTimpactReport -Response $Response
    }
    else {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules'
        if ($PSBoundParameters.ContainsKey('ReplaceRules')) {
            $Uri += "?replace_all_rules=$true"
        }
        else {
            $Uri += "?replace_all_rules=$false"
        }

        try {
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SVTtask = $Task
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    it using Remove-SVTpolicyRule and New-SVTpolicyRule respectively, to update the backup destination.

    Rule numbers start from 0 and increment by 1. Use Get-SVTpolicy to identify the rule you want to update.

    You can also display an impact report rather than performing the change.
.PARAMETER PolicyName
    The name of the backup policy to update
.PARAMETER RuleNumber
    The number of the policy rule to update. Use Get-SVTpolicy to show policy information
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
    PS C:\> Update-SVTPolicyRule -Policy Gold -RuleNumber 2 -Weekday Sun,Fri -StartTime 20:00 -EndTime 23:00

    Updates rule number 2 in the specified policy with a new weekday policy. start and finish times. This command 
    inherits the existing retention, frequency, and application consistency settings from the existing rule.
.EXAMPLE
    PS C:\> Update-SVTPolicyRule -Policy Bronze -RuleNumber 1 -LastDay
    PS C:\> Update-SVTPolicyRule Bronze 1 -LastDay
    
    Both commands update rule 1 in the specified policy with a new day. All other settings are inherited from
    the existing backup policy rule.
.EXAMPLE
    PS C:\> Update-SVTPolicyRule Silver 3 -MonthDay 1,7,14,21 -RetentionDay 30

    Updates the existing rule 3 in the specified policy to perform backups four times a month on the specified 
    days and retains the backup for 30 days.
.EXAMPLE
    PS C:\> Update-SVTPolicyRule Gold 1 -All -RetentionHour 1 -FrequencyMin 20 -StartTime 9:00 -EndTime 17:00

    Updates the existing rule 1 in the Gold policy to backup 3 times per hour every day during office hours and 
    retain each backup for 1 hour. (Note: -RetentionHour takes precedence over -RetentionDay if both are 
    specified).
.EXAMPLE
    PS C:\> Update-SVTpolicyRule Silver 2 -All -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that updating this policy rule would 
    make to the system. The report shows projected daily backup rates and total retained backup rates.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    PSCustomObject
.NOTES
- Changing the destination is not supported.
- Replacing all policy rules is not supported. Use New-SVTpolicyRule instead.
- Changing ConsistencyType to anything other than None or Default doesn't appear to work. 
- Use Remove-SVTpolicyRule and New-SVTpolicyRule to update ConsistencyType to VSS.
#>
function Update-SVTpolicyRule {
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
        $Policy = Get-SVTpolicy -PolicyName $PolicyName -RuleNumber $RuleNumber -ErrorAction Stop 
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
    # true if consitency_type is VSS or DEFAULT. Otherwise the API sets it to NONE.
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
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }
        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + 
        '/impact_report/edit_rules?replace_all_rules=false'

        try {
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SVTimpactReport -Response $Response
    }
    else {
        $Body = $Body | ConvertTo-Json
        Write-Verbose $Body

        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }
        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules/' + $RuleId

        try {
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Put -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SVTtask = $Task
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

<#
.SYNOPSIS
    Deletes a backup rule from an existing HPE SimpliVity backup policy
.DESCRIPTION
    Delete an existing rule from a HPE SimpliVity backup policy. You must specify the policy name and 
    the rule number to be removed.

    Rule numbers start from 0 and increment by 1. Use Get-SVTpolicy to identify the rule you want to delete.

    You can also display an impact report rather than performing the change.
.PARAMETER PolicyName
    Specify the policy containing the policy rule to delete
.PARAMETER RuleNumber
    Specify the number assigned to the policy rule to delete. Use Get-SVTpolicy to show policy information
.PARAMETER ImpactReportOnly
    Rather than remove the policy rule, display a report showing the impact this change would make. The report 
    shows projected daily backup rates and new total retained backups given the frequency and retention settings
    for the specified backup policy.
.EXAMPLE
    PS C:\> Remove-SVTPolicyRule -Policy Gold -RuleNumber 2

    Removes rule number 2 in the specified backup policy
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
    PSCustomObject
.NOTES
    There seems to be a bug, you cannot remove rule 0 if there are other rules. You can use New-SVTpolicyRule 
    with the -ReplaceRules parameter to remove all rules, 
    or remove the other rules first.
#>
function Remove-SVTpolicyRule {
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
        $Policy = Get-SVTpolicy -PolicyName $PolicyName -RuleNumber $RuleNumber -ErrorAction Stop
        
        $PolicyId = $Policy | Select-Object -ExpandProperty PolicyId -Unique
        $RuleId = $Policy | Select-Object -ExpandProperty RuleId -Unique
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($PolicyId)) {
        $Message = 'Specified policy name or Rule number not found. Use Get-SVTpolicy to determine ' +
        'rule number for the rule you want to delete'
        throw $Message
    }

    if ($ImpactReportOnly) {
        # Delete rule impact performed, show report
        try {
            $Header = @{
                'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'        = 'application/json'
                'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
            }
            $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules/' + 
            $RuleId + '/impact_report/delete_rule'
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        # Schedule impact performed, show report
        Get-SVTimpactReport -Response $Response
    }
    else {
        # Delete the backup policy rule
        try {
            $Header = @{
                'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'        = 'application/json'
            }
            $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules/' + $RuleId
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $Task
        $global:SVTtask = $Task
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Get-SVTpolicy
    PS C:\> Rename-SVTpolicy -PolicyName Silver -NewPolicyName Gold

    The first command confirms the new policy name doesn't exist. 
    The second command renames the backup policy as specified.
.EXAMPLE
    PS C:\> Rename-SVTpolicy Silver Gold

    Renames the backup policy as specified
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Rename-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$NewPolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
        Select-Object -ExpandProperty PolicyId -Unique

        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rename'

        $Body = @{ 'name' = $NewPolicyName } | ConvertTo-Json
        Write-Verbose $Body
    }
    catch {
        throw $_.Exception.Message
    }

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Removes a HPE SimpliVity backup policy
.DESCRIPTION
    Removes a HPE SimpliVity backup policy, providing it is not in use be any datastores or virtual machines.
.PARAMETER PolicyName
    The policy to delete
.EXAMPLE
    PS C:\> Get-SVTvm | Select VmName, PolicyName
    PS C:\> Get-SVTdatastore | Select DatastoreName, PolicyName
    PS C:\> Remove-SVTpolicy -PolicyName Silver

    Confirm there are no datastores or VMs using the backup policy and then delete it.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Remove-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Name')]
        [System.String]$PolicyName
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
        Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    # Confirm the policy is not in use before deleting it. To do this, check both datastores and VMs
    $UriList = @(
        $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/virtual_machines'
        $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/datastores'
    )
    [Bool]$ObjectFound = $false
    [String]$Message = ''
    Foreach ($Uri in $UriList) {
        try {
            $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
        $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Delete -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Suspend-SVTpolicy -Federation

    Suspends backup policies for the entire federation

    NOTE: This command will only work when connected to an OmniStack virtual controller, (not when connected
    to a management virtual appliance)
.EXAMPLE
    PS C:\> Suspend-SVTpolicy -ClusterName Prod

    Suspend backup policies for the specified cluster
.EXAMPLE
    PS C:\> Suspend-SVTpolicy -HostName host01

    Suspend backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Suspend-SVTpolicy {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/policies/suspend'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        try {
            $TargetId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
            Select-Object -ExpandProperty ClusterId

            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    elseif ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $TargetId = Get-SVThost -HostName $HostName -ErrorAction Stop | 
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
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    PS C:\> Resume-SVTpolicy -Federation

    Resumes backup policies for the federation

    NOTE: This command will only work when connected to an OmniStack virtual controller, (not when connected
    to a management virtual appliance)
.EXAMPLE
    PS C:\> Resume-SVTpolicy -ClusterName Prod

    Resumes backup policies for the specified cluster
.EXAMPLE
    PS C:\> Resume-SVTpolicy -HostName host01

    Resumes backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Resume-SVTpolicy {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies/resume'

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        try {
            $TargetId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | 
            Select-Object -ExpandProperty ClusterId

            $TargetType = 'omnistack_cluster'
        }
        catch {
            throw $_.Exception.Message
        }
    }
    elseif ($PSBoundParameters.ContainsKey('HostName')) {
        try {
            $TargetId = Get-SVThost -HostName $HostName -ErrorAction Stop | 
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
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Display a report showing information about HPE SimpliVity backup rates and limits
.DESCRIPTION
    Display a report showing information about HPE SimpliVity backup rates and limits
.EXAMPLE
    PS C:\> Get-SVTpolicyScheduleReport

.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTpolicyScheduleReport {
    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies/policy_schedule_report'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
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
    parameters to limit the objects returned. Also accepts output from Get-SVThost as input.

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
    PS C:\> Get-SVTvm

    Shows all virtual machines in the Federation with state "ALIVE", which is the default state
.EXAMPLE
    PS C:\> Get-SVTvm -VmName Server2016-01
    PS C:\> Get-SVTvm -Name Server2016-01
    PS C:\> Get-SVTvm Server2016-01

    All three commands perform the same action - show information about the specified virtual machine(s) with 
    state "ALIVE", which is the default state

    The first command uses the parameter name; the second uses an alias for VmName; the third uses positional
    parameter, which accepts a VM name.
.EXAMPLE
    PS C:\> Get-SVTvm -State DELETED
    PS C:\> Get-SVTvm -State ALIVE,REMOVED,DELETED

    Shows all virtual machines in the Federation with the specified state(s)
.EXAMPLE
    PS C:\> Get-SVTvm -DatastoreName DS01,DS02

    Shows all virtual machines residing on the specified datastore(s)
.EXAMPLE
    PS C:\> Get-SVTvm VM1,VM2,VM3 | Out-GridView -Passthru | Export-CSV FilteredVmList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports
    this to a CSV
.EXAMPLE
    PS C:\> Get-SVTvm -HostName esx04 | Select-Object Name, SizeGB, Policy, HAstatus

    Show the VMs from the specified host. Show the selected properties only.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.VirtualMachine
.NOTES
Known issues:
OMNI-69918 - GET calls for virtual machine objects may result in OutOfMemortError when exceeding 8000 objects
#>
function Get-SVTvm {
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
        [System.String]$HostName, # API only accepts one host id

        [Parameter(Mandatory = $false)]
        [ValidateSet('ALIVE', 'DELETED', 'REMOVED')]
        [System.String[]]$State = 'ALIVE',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 5000)]   # Limited to avoid out of memory errors (OMNI-69918) (Runtime error over 5000)
        [System.Int32]$Limit = 500
    )

    $Header = @{
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
    }

    $Uri = "$($global:SVTconnection.OVC)/api/virtual_machines" +
    '?show_optional_fields=true' +
    '&case=insensitive' +
    '&offset=0' +
    "&limit=$Limit" +
    "&state=$($State -join ',')"

    # Get hosts so we can convert HostId to the more useful HostName in the virtual machine object
    $Allhost = Get-SVThost

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
            $HostName = Resolve-SVTFullHostName $HostName $Allhost.HostName -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
        $HostId = $Allhost | Where-Object HostName -eq $HostName | Select-Object -ExpandProperty HostId
        $Uri += "&host_id=$HostId"
    }

    if ($PSBoundParameters.ContainsKey('ClusterName')) {
        $Uri += "&omnistack_cluster_name=$($ClusterName -join ',')"
    }

    if ($PSBoundParameters.ContainsKey('DataStoreName')) {
        $Uri += "&datastore_name=$($DatastoreName -join ',')"
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri "$Uri" -Header $Header -Method Get -ErrorAction Stop
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

    if ($PSBoundParameters.ContainsKey('VmName') -and -not $Response.virtual_machines.name) {
        throw "Specified virtual machine(s) $VmName not found"
    }

    if ($PSBoundParameters.ContainsKey('VmId') -and -not $Response.virtual_machines.name) {
        throw "Specified virtual machine ID(s) $VmId not found"
    }

    $Response.virtual_machines | ForEach-Object {

        $ThisHost = $Allhost | Where-Object HostID -eq $_.host_id | Select-Object -ExpandProperty HostName
        if ($null -eq $ThisHost -and $_.state -eq 'ALIVE') {
            $ThisHost = '*ComputeNode'
        }

        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.VirtualMachine'
            PolicyId                 = $_.policy_id
            CreateDate               = ConvertFrom-SVTutc -Date $_.created_at
            PolicyName               = $_.policy_name
            DataStoreName            = $_.datastore_name
            ClusterName              = $_.omnistack_cluster_name
            DeletedDate              = ConvertFrom-SVTutc -Date $_.deleted_at
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
            HypervisorVmPowerState   = $_.hypervisor_virtual_machine_power_state
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
    PS C:\> Get-SVTvmReplicaSet

    Displays the primary and secondary locations for all virtual machine replica sets.
.INPUTS
    system.string
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTvmReplicaSet {
    [CmdletBinding(DefaultParameterSetName = 'ByVm')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVm')]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByDatastore')]
        [System.String[]]$DataStoreName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCluster')]
        [System.String[]]$ClusterName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByHost')]
        [System.String]$HostName
    )

    begin {
        $Allhost = Get-SVThost

        if ($PSBoundParameters.ContainsKey('VmName')) {
            $VmObj = Get-SVTvm -VmName $VmName
        }
        elseif ($PSBoundParameters.ContainsKey('DataStoreName')) {
            $VmObj = Get-SVTvm -DataStoreName $DataStoreName
        }
        elseif ($PSBoundParameters.ContainsKey('ClusterName')) {
            $VmObj = Get-SVTvm -ClusterName $ClusterName
        }
        elseif ($PSBoundParameters.ContainsKey('HostName')) {
            $VmObj = Get-SVTvm -HostName $HostName
        }
        else {
            $VmObj = Get-SVTvm  # default is all VMs
        }
    }

    process {
        foreach ($VM in $VmObj) {
            $PrimaryId = $VM.ReplicaSet | Where-Object role -eq 'PRIMARY' | 
            Select-Object -ExpandProperty id

            $SecondaryId = $VM.ReplicaSet | Where-Object role -eq 'SECONDARY' | 
            Select-Object -ExpandProperty id

            $PrimaryHost = $Allhost | Where-Object HostId -eq $PrimaryId | 
            Select-Object -ExpandProperty HostName

            $SecondaryHost = $Allhost | Where-Object HostId -eq $SecondaryId | 
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
    PS C:\> New-SVTclone -VmName MyVm1

    Create a clone with the default name 'MyVm1-clone-200212102304', where the suffix is a date stamp in 
    the form 'yyMMddhhmmss'
.EXAMPLE
    PS C:\> New-SVTclone -VmName Server2016-01 -CloneName Server2016-Clone
    PS C:\> New-SVTclone -VmName Server2016-01 -CloneName Server2016-Clone -ConsistencyType NONE

    Both commands do the same thing, they create an application consistent clone of the specified 
    virtual machine, using a snapshot
.EXAMPLE
    PS C:\> New-SVTclone -VmName RHEL8-01 -CloneName RHEL8-01-New -ConsistencyType DEFAULT

    Create a crash-consistent clone of the specified virtual machine
.EXAMPLE
    PS C:\> New-SVTclone -VmName Server2016-06 -CloneName Server2016-Clone -ConsistencyType VSS

    Creates an application consistent clone of the specified Windows VM, using a VSS snapshot. The clone
    will fail for None-Windows virtual machines.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
#>
function New-SVTclone {
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
        'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
    }

    try {
        $VmId = Get-SVTvm -VmName $VmName -ErrorAction Stop | Select-Object -ExpandProperty VmId
        $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/clone'
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
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
    $global:SVTtask = $Task
    $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
}

<#
.SYNOPSIS
    Move an existing virtual machine from one HPE SimpliVity datastore to another
.DESCRIPTION
    Relocates the specified virtual machine(s) to a different datastore in the federation. The datastore can be
    in the same or a different datacenter. Consider the following when moving a virtual machine:
    1. You must power off the OS guest before moving, otherwise the operation fails
    2. In its new location, make sure the moved VM(s) boots up after the local OVC and shuts down before it
    3. Any pre-move backups (local or remote) stay associated with the VM(s) after it/they moves. You can 
       use these backups to restore the moved VM(s).
    4. HPE OmniStack only supports one move operation per VM at a time. You must wait for the task to 
       complete before attempting to move the same VM again
    5. If moving VM(s) out of the current cluster, DRS rules (created by the Intelligent Workload Optimizer) 
       will vMotion the moved VM(s) to the destination
.PARAMETER VmName
    The name(s) of the virtual machines you'd like to move
.PARAMETER DatastoreName
    The destination datastore
.EXAMPLE
    PS C:\> Move-SVTvm -VmName MyVm -Datastore DR-DS01

    Moves the specified VM to the specified datastore
.EXAMPLE
    PS C:\> "VM1", "VM2" | Move-SVTvm -Datastore DS03

    Moves the two VMs to the specified datastore
.EXAMPLE
    PS C:\> Get-VM | Where-Object VmName -match "WEB" | Move-SVTvm -Datastore DS03
    PS C:\> Get-SVTtask

    Move VM(s) with "Web" in their name to the specified datastore. Use Get-SVTtask to monitor the progress
    of the move task(s)
.INPUTS
    system.string
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Move-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [Alias('Name')]
        [System.String]$VmName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$DataStoreName
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.5+json'
        }

        try {
            $DataStoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | 
            Select-Object -ExpandProperty DatastoreId
        }
        catch {
            throw $_.Exception.Message
        }
    }
    process {
        foreach ($VM in $VmName) {
            try {
                $VmObj = Get-SVTvm -VmName $VM -ErrorAction Stop
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmObj.VmId + '/move'

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
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                $Task
                [array]$AllTask += $Task
            }
            catch {
                Write-Warning "$($_.Exception.Message), move failed for VM $VM"
            }
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
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
    the pipeline, using Get-SVTvm. This is more efficient (single call to the SimpliVity API).
.PARAMETER ImpactReportOnly
    Rather than change the backup policy on one or more virtual machines, display a report showing the impact 
    this action would make. The report shows projected daily backup rates and new total retained backups given 
    the frequency and retention settings for the given backup policy.
.PARAMETER Username
    When setting the user credentials, specify the username 
.PARAMETER Password
    When setting the user credentials, the password must be entered as a secure string (not as a parameter)
.EXAMPLE
    PS C:\> Get-SVTvm -Datastore DS01 | Set-SVTvmPolicy Silver

    Changes the backup policy for all VMs on the specified datastore to the backup policy named 'Silver'
.EXAMPLE
    Set-SVTvmPolicy Silver VM01

    Using positional parameters to apply a new backup policy to the VM
.EXAMPLE
    Get-SVTvm -Policy Silver | Set-SVTvmPolicy -PolicyName Gold -ImpactReportOnly

    No changes are made. Displays an impact report showing the effects that changing all virtual machines with
    the Silver backup policy to the Gold backup policy would make to the system. The report shows projected 
    daily backup rates and total retained backup rates. 
.EXAMPLE
    PS C:\> Set-SVTvm -VmName MyVm -Username svc_backup

    Prompts for the password of the specified account and sets the VSS credentials for the virtual machine.
.EXAMPLE
    PS C:\> "VM1", "VM2" | Set-SVTvm -Username sugarstar\backupadmin

    Prompts for the password of the specified account and sets the VSS credentials for the two virtual machines.
    The command contacts the running Windows guest to confirm the validity of the password before setting it.
.EXAMPLE
    PS C:\> Get-VM Server2016-01 | Set-SVTvm -Username administrator
    PS C:\> Get-VM Server2016-01 | Select-Object VmName, AppAwareVmStatus

    Set the credentials for the specified virtual machine and then confirm they are set properly.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
    PSCustomObject
.NOTES
#>
function Set-SVTvm {
    [CmdletBinding(DefaultParameterSetName = 'SetPolicy')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SetPolicy')]
        [Alias('Policy')]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SetCredential',
            ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SetPolicy',
            ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'SetPolicy')]
        [switch]$ImpactReportOnly,

        [Parameter(Mandatory = $false, ParameterSetName = 'SetPolicy',
            ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VmId,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SetCredential')]
        [System.String]$Username,

        [Parameter(Mandatory = $true, ParameterSetName = 'SetCredential')]
        [System.Security.SecureString]$Password
    )

    begin {
        # This header is used by /backup_parameters (set credentials) and /policy_impact_report/apply_policy. 
        # Not by /set_policy. This is fixed later
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.14+json'
        }

        if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
            $VmList = @()
            try {
                $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | 
                Select-Object -ExpandProperty PolicyId -Unique
            }
            catch {
                throw $_.Exception.Message
            }

            if ($ImpactReportOnly) {
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/policy_impact_report/apply_policy'
            }
            else {
                # Fix header for /set_policy API call
                $Header.'Content-Type' = 'application/vnd.simplivity.v1.5+json'
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/set_policy'
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
        # VM objects passed in from Get-SVTvm
        if ($VmId) {
            if ($PSCmdlet.ParameterSetName -eq 'SetPolicy') {
                # Both forms of the policy command (set report) uses a hash containing VM Ids (passed in)
                $VmList += $VmId
            }
            else {
                # Run a task to set user creds on each VM (passed in)
                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/backup_parameters'
                try {
                    $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
                        $VmList += Get-SVTvm -VmName $VM -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    }
                    catch {
                        throw $_.Exception.Message
                    }
                }
                else {
                    # Run a task to set user creds on each VM (specified)
                    try {
                        $VmObj = Get-SVTvm -VmName $VM -ErrorAction Stop
                        $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmObj.VmId + 
                        '/backup_parameters'
                    }
                    catch {
                        throw $_.Exception.Message
                    }
                    try {
                        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
    
            if ($ImpactReportOnly) {
                # Schedule impact performed, show report
                Get-SVTimpactReport -Response $Response
            }
            else {
                #Task peformed, show the task
                $Response
                $global:SVTtask = $Response
                $null = $SVTtask
            }
        }
        else {
            # Work for set user credentials is done in process loop, just output the task Ids
            $global:SVTtask = $AllTask
            $null = $SVTtask
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
    the pipeline, using Get-SVTvm. This is more efficient (single call to the SimpliVity API).
.EXAMPLE
    PS C:\> Stop-SVTvm -VmName MyVm

    Stops the specified virtual machine
.EXAMPLE
    PS C:\> Get-SVTvm -Datastore DS01 | Stop-SVTvm

    Stops all the VMs on the specified datastore
.EXAMPLE
    PS C:\> Stop-SVTvm -VmName Server2016-01,Server2016-02,Server2016-03

    Stops the specified virtual machines
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Stop-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VmId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.11+json'
        }
    }

    process {
        if ($VmId) {
            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/power_off'
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
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
                    $VmObj = Get-SVTvm -VmName $VM -ErrorAction Stop
                    $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmObj.VmId + '/power_off'
                }
                catch {
                    throw $_.Exception.Message
                }

                try {
                    $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
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
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
        $null = $SVTtask # Stops PSScriptAnalzer complaining about variable assigned but never used
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
    the pipeline, using Get-SVTvm. This is more efficient (single call to the SimpliVity API).
.EXAMPLE
    PS C:\> Start-SVTvm -VmName MyVm

    Starts the specified virtual machine
.EXAMPLE
    PS C:\> Get-SVTvm -ClusterName DR01 | Start-SVTvm -VmName MyVm

    Starts the virtual machines in the specified cluster
.EXAMPLE
    PS C:\> Start-SVTvm -VmName Server2016-01,RHEL8-01

    Starts the specfied virtual machines
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Start-SVTvm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, 
            ValueFromPipelinebyPropertyName = $true)]
        [Alias('Name')]
        [System.String[]]$VmName,

        [Parameter(Mandatory = $false, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VmId
    )

    begin {
        $Header = @{
            'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'        = 'application/json'
            'Content-Type'  = 'application/vnd.simplivity.v1.11+json'
        }
    }

    process {
        if ($VmId) {
            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/power_on'
            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
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
                    $VmObj = Get-SVTvm -VmName $VM -ErrorAction Stop
                    $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmObj.VmId + '/power_on'
                }
                catch {
                    throw $_.Exception.Message
                }

                try {
                    $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
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
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
        $null = $SVTtask #Stops PSScriptAnalzer complaining about variable assigned but never used
    }
}

#endregion VirtualMachine
