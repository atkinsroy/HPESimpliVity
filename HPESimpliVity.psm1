###############################################################################################################
# HPESimpliVity.psm1
#
# Description:
#   This module provides management cmdlets for HPE SimpliVity via the
#   REST API. This module has tested with both VMware and Hyper-V.
#
# Website:
#   https://github.com/atkinsroy/HPESimpliVity
#
#   VERSION 1.1.5
#
#   AUTHOR
#   Roy Atkins    HPE Pointnext Services
#
##############################################################################################################

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

#region Utility

# Helper function for Invoke-RestMethod to handle REST errors in one place. The calling function then re-throws the error,
# generated here. This cmdlet either outputs a custom task object if the REST API response is a task object, or otherwise the raw JSON.

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
    
    [int]$Retrycount = 0
    [bool]$Stoploop = $false
    do {
        try {
            if ($Body) {
                $Response = Invoke-RestMethod -Uri $Uri -Headers $Header -Body $Body -Method $Method -ErrorAction Stop
            }
            else {
                $Response = Invoke-RestMethod -Uri $Uri -Headers $Header -Method $Method -ErrorAction Stop
            }
            $Stoploop = $true
        }
        catch [System.Management.Automation.RuntimeException] {
            if ($_.Exception.Message -match "Unauthorized") {
                if ($Retrycount -ge 3) {
                    # Exit after 3 retries
                    throw "Runtime error: Session expired and could not reconnect"
                }
                else {
                    $Retrycount += 1
                    Write-Verbose "Session expired, reconnecting..."
                    $OVC = $SVTconnection.OVC -replace 'https://',''
                    $Retry = Connect-SVT -OVC $OVC -Credential $SVTconnection.Credential

                    # Update the json header with the new token for the retry
                    $Header = @{'Authorization' = "Bearer $($Retry.Token)"
                        'Accept'                = 'application/json' 
                    }
                }
            }
            elseif ($_.Exception.Message -match "The hostname could not be parsed") {
                throw "Runtime error: You must first log in using Connect-SVT"
            }
            else {
                throw "Runtime error: $($_.Exception.Message)"
            }
        }
        catch {
            # Catch any other error - API might provide a message
            throw "An unexpected error occured: $($_.Exception.Message)"
        }
    }
    until ($Stoploop -eq $true)

    # If the JSON output is a task, convert it to a custom object of type 'HPE.SimpliVity.Task' and pass this back to the
    # calling cmdlet. A lot of cmdlets produce task object types, so this cuts out repetition in the module.
    # Note: $Response.task is incorrectly true with /api/omnistack_clusters/throughput, so added a check for this.
    if ($Response.task -and $URI -notmatch '/api/omnistack_clusters/throughput') {
        
        $culture = (Get-Culture).DateTimeFormat
        $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
        $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
        $LocalFormat = "$LocalDate $LocalTime"
        
        $Response.task | ForEach-Object {
            if ($_.start_time -as [datetime]) {
                $StartTime = Get-Date -Date $_.start_time -Format $LocalFormat
            }
            else {
                $StartTime = $null
            }
            if ($_.end_time -as [datetime]) {
                $EndTime = Get-Date -Date $_.end_time -Format $LocalFormat
            }
            else {
                $EndTime = $null
            }
            [PSCustomObject]@{
                PStypeName      = 'HPE.SimpliVity.Task'
                TaskId          = $_.id
                State           = $_.state
                AffectedObjects = $_.affected_objects
                ErrorCode       = $_.error_code
                StartTime       = $StartTime
                EndTime         = $EndTime
                Message         = $_.message
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
    Show information about tasks that are currently executing or have finished executing in HPE SimpliVity
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
.INPUTS
    System.String
    HPE.SimpliVity.Task
.OUTPUTS
    HPE.SimpliVity.Task
.EXAMPLE
    PS C:\> Get-SVTtask

    Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates a SimpliVity resource
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
#>
function Get-SVTtask {
    [CmdletBinding()]
    param(
        # by default, use the global variable. i.e. the output from the last task producing cmdlet in this session
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
            $Uri = $global:SVTconnection.OVC + '/api/tasks/' + $ThisTask.TaskId

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
    PS C:\>Connect-SVT -OVC <FQDN or IP Address of OVC>

    This will securely prompt you for credentials
.EXAMPLE
    PS C:\>$Cred = Get-Credential -Message 'Enter Credentials'
    PS C:\>Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $Cred

    Create the credential first, then pass it as a parameter.
.EXAMPLE
    PS C:\>$CredFile = "$((Get-Location).Path)\OVCcred.XML"
    PS C:\>Get-Credential -Credential '<username@domain>'| Export-CLIXML $CredFile

    Another way is to store the credential in a file (as above), then connect to the OVC using:
    PS C:\>  Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $(Import-CLIXML $CredFile)

    or:
    PS C:\>$Cred = Import-CLIXML $CredFile
    PS C:\>Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $Cred

    This method is useful in non-iteractive sessions. Once the file is created, run the Connect-SVT
    command to connect and reconnect to the OVC, as required.
.NOTES
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

    # 2 ways to securely authenticate - via an existing credential object or prompt for a credential
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
#>
Function Get-SVTversion {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/version'

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
.PARAMETER Hostname
    Show performance metrics for the specified SimpliVity node(s)
.PARAMETER VMName
    Show performance metrics for the specified virtual machine(s) hosted on SimpliVity storage
.PARAMETER OffsetHour
    Show performance metrics starting from the specified offset (hours from now, default is now)
.PARAMETER Hour
    Show performance metrics for the specifed number of hours (starting from OffsetHour)
.PARAMETER Resolution
    The resolution in seconds, minutes, hours or days
.PARAMETER Chart
    Create a chart instead of showing performance metrics. The chart file is saved to the current folder. One chart is
    created for each object (e.g. cluster, host or VM)
.EXAMPLE
    PS C:\>Get-SVTmetric -ClusterName Production

    Shows performance metrics about the specified cluster, using the default hour setting (24 hours) and resolution (every hour)
.EXAMPLE
    PS C:\>Get-SVThost | Get-SVTmetric -Hour 1 -Resolution SECOND

    Shows performance metrics for all hosts in the federation, for every second of the last hour
.EXAMPLE
    PS C:\>Get-SVTvm | Where VMname -match "SQL" | Get-SVTmetric

    Show performance metrics for every VM that has "SQL" in its name
.EXAMPLE
    PS C:\>Get-SVTcluster -ClusterName DR | Get-SVTmetric -Hour 1440 -Resolution DAY

    Show daily performance metrics for the last two months for the specified cluster
.EXAMPLE
    PS C:\>Get-SVThost | Get-Metric -Chart -Verbose

    Create chart(s) instead of showing the metric data. Chart files are created in the current folder.
    Use filtering when creating charts for virtual machines to avoid creating a lot of charts.
.EXAMPLE
    PS C:\>Get-SVThost -HostName MyHost | Get-Metric -Chart | Foreach-Object {Invoke-Item $_}

    Create a metrics chart for the specified host and display it. Note that Invoke-Item only works with
    image files when the Desktop Experience Feature is installed (may not be installed on some servers)
.INPUTS
    System.String
    HPE.SimpliVity.Cluster
    HPE.SimpliVity.Host
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Metric
.NOTES
#>
function Get-SVTmetric {
    [CmdletBinding(DefaultParameterSetName = 'Host')]
    param
    (
        [parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Cluster')]
        [string[]]$ClusterName,

        [parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Host')]
        [string[]]$HostName,

        [parameter(Mandatory = $true, Position = 0, ParameterSetName = 'VirtualMachine')]
        [string[]]$VMName,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'SVTobject')]
        [psobject]$SVTobject,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$OffsetHour = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Hour = 24,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'HOUR',

        [Parameter(Mandatory = $false)]
        [Switch]$Chart
    )

    begin {
        $VerbosePreference = 'Continue'

        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
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

        if ($Resolution -eq 'SECOND' -and $range -gt 7200 ) {
            Write-Warning 'Using the resolution of SECOND beyond a range of 2 hours can take a long time to complete'
        }
        if ($Resolution -eq 'MINUTE' -and $range -gt 86400 ) {
            Write-Warning 'Using the resolution of MINUTE beyond a range of 24 hours can take a long time to complete'
        }
        $culture = (Get-Culture).DateTimeFormat
        $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
        $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
        $LocalFormat = "$LocalDate $LocalTime"
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
        else {
            $InputObject = $VMName
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
                $ObjectName = $Item.VMname
            }
            elseif ($ClusterName) {
                try {
                    $ClusterId = Get-SVTcluster -ClusterName $Item -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
                    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/metrics'
                    $ObjectName = $Item
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            elseif ($HostName) {
                try {
                    $HostId = Get-SVThost -HostName $Item -ErrorAction Stop | Select-Object -ExpandProperty HostId
                    $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/metrics'
                    $ObjectName = $Item
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                try {
                    $VmId = Get-SVTvm -VMname $Item -ErrorAction Stop | Select-Object -ExpandProperty VmId
                    $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/metrics'
                    $ObjectName = $Item
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            Write-verbose "Object name is $ObjectName ($TypeName)"

            $Uri = $Uri + "?time_offset=$Offset&range=$Range&resolution=$Resolution"

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            # Unpack the Json into a Custom object. This outputs each Metric with a date and some values
            $CustomObject = $Response.metrics | foreach-object {
                $MetricName = (Get-Culture).TextInfo.ToTitleCase($_.name)
                $_.data_points | ForEach-Object {
                    if ($_.date -as [DateTime]) {
                        $Date = Get-Date -Date $_.date -Format $LocalFormat
                    }
                    else {
                        $Date = $null
                    }
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = $Date
                        Read  = $_.reads
                        Write = $_.writes
                    }
                }
            } 

            #Transpose the custom object to return each date with read and write for each metric
            $MetricObject = $CustomObject | Sort-Object -Property Date,Name | Group-Object -Property Date | ForEach-Object {
                $Property = [ordered]@{
                    PStypeName = 'HPE.SimpliVity.Metric'
                    Date       = $_.Name
                }

                [string]$prevname=''
                $_.Group | Foreach-object {
                    # We expect to see just 3 records per date. However, sometimes there are 6. 
                    # So check for duplicates before creating the key.
                    If ($_.name -ne $prevname) {    
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

            if ($chart) {
                [array]$ChartObject += $MetricObject
            }
            else {
                $MetricObject
            }   
        } #end for
    } #end process

    end {
        if ($Chart) {
            Get-SVTmetricChart -Metric $ChartObject -TypeName $TypeName 
        }
    }
}

# Helper function for Get-SVTmetric
function Get-SVTmetricChart {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$Metric,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$TypeName
    )

    if ($PSVersionTable.PSVersion.Major -gt 5) {
        throw "Microsoft Chart Controls are not currently supported with PowerShell Core, use Windows PowerShell"
    }

    $ObjectList = $Metric.ObjectName | Select-Object -Unique
    #$ObjectTotal = $ObjectList | Measure-Object | Select-Object -ExpandProperty Count
    
    $Path = Get-Location
    $Culture = Get-Culture
    $StartDate = $Metric | Select-Object -First 1 -ExpandProperty Date
    $EndDate = $Metric | Select-Object -Last 1 -ExpandProperty Date
    $ChartLabelFont = 'Arial, 8pt'
    $ChartTitleFont = 'Arial, 12pt'
    $DateStamp = Get-Date -Format "yyMMddhhmmss"

    # define an object to determine the best inverval on the Y axis, given a maximum value
    $Ylimit = (0,10000,20000,40000,80000,160000,320000,640000,1280000,2560000,5120000,10240000,20480000)
    $Yinterval = (200,500,1000,5000,10000,15000,20000,50000,75000,100000,250000,400000,1000000)
    $Yaxis = 0..11 | foreach-object {
        [PSCustomObject]@{
            Limit = $Ylimit[$_]
            Interval = $YInterval[$_]
        }
    }

    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    foreach ($Instance in $ObjectList) {
        $DataSource = $Metric | Where-Object ObjectName -eq $Instance
        $DataPoint = $DataSource | Measure-Object | Select-Object -ExpandProperty Count

        # chart object
        $Chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
        $Chart1.Width = 1200
        $Chart1.Height = 600
        $Chart1.BackColor = [System.Drawing.Color]::LightGray

        # title
        try {
            $ShortName = ([ipaddress]$Instance).IPAddressToString
        }
        catch {
            $ShortName = $Instance -split '\.' | Select-Object -First 1
        }
        [void]$Chart1.Titles.Add("$($TypeName): $ShortName - Metrics from $StartDate to $EndDate")
        $Chart1.Titles[0].Font = "Arial,16pt"
        $Chart1.Titles[0].Alignment = "topLeft"

        # chart area
        $AxisEnabled = New-Object System.Windows.Forms.DataVisualization.Charting.AxisEnabled
        $AxisType = New-Object System.Windows.Forms.DataVisualization.Charting.AxisType
        $Area1 = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Area1.Name = "ChartArea1"
        $Area1.AxisX.Title = "Date"
        $Area1.AxisX.TitleFont = $ChartTitleFont
        $Area1.AxisX.LabelStyle.Font = $ChartLabelFont

        # to determine an appropriate X axis interval, find the number of data points in the data
        $Interval = [math]::Round($DataPoint / 24) #show 24 dates on X axis only
       
        if ($Interval -lt 1) {
            $Area1.AxisX.Interval = 1
        }
        else {
            $Area1.AxisX.Interval = $Interval
        }

        $Area1.AxisY.Title = "IOPS and Latency (milliseconds)"
        $Area1.AxisY.TitleFont = $ChartTitleFont
        $Area1.AxisY.LabelStyle.Font = $ChartLabelFont

        if($Interval -gt 12) {
            $BorderWidth = 1  #reduce line weight for charts with long time ranges
        }
        else {
            $BorderWidth = 2
        }

        # To determine an appropriate interval on Y axis, find the maximum value in the data.
        $MaxArray = @(
            $DataSource | Measure-Object -Property LatencyRead -Maximum | Select-Object -ExpandProperty Maximum
            $DataSource | Measure-Object -Property LatencyWrite -Maximum | Select-Object -ExpandProperty Maximum
            $DataSource | Measure-Object -Property IopsRead -Maximum | Select-Object -ExpandProperty Maximum
            $DataSource | Measure-Object -Property IopsWrite -Maximum | Select-Object -ExpandProperty Maximum
        )
        $Max = 0  #ensure Y axis has appropriate interval
        $MaxArray | Foreach-Object {
            if($_ -gt $Max) {
                $Max = $_
            }
        }

        # determine an appropriate Yaxis Inverval.
        $Yaxis | ForEach-Object {
            if ($Max -gt $_.Limit) {
                $Yint = $_.Interval
            }
        }
        $Area1.AxisY.Interval = $Yint

        # title for second Y axis
        $Area1.AxisY2.Title = "Throughput (Mbps)"
        $Area1.AxisY2.TitleFont = $ChartTitleFont
        $Area1.AxisY2.LabelStyle.Font = $ChartLabelFont
        $Area1.AxisY2.LineColor = [System.Drawing.Color]::Transparent
        $Area1.AxisY2.MajorGrid.Enabled = $false
        $Area1.AxisY2.Enabled = $AxisEnabled::true

        # Add Area to chart
        $Chart1.ChartAreas.Add($Area1)
        $Chart1.ChartAreas["ChartArea1"].AxisY.LabelStyle.Angle = 0
        $Chart1.ChartAreas["ChartArea1"].AxisX.LabelStyle.Angle = -45

        # legend to chart
        $Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
        $Legend.name = "Legend1"
        $Chart1.Legends.Add($Legend)

        # data series
        [void]$Chart1.Series.Add("IopsRead")
        $Chart1.Series["IopsRead"].YAxisType = $AxisType::Primary
        $Chart1.Series["IopsRead"].ChartType = "Line"
        $Chart1.Series["IopsRead"].BorderWidth = $BorderWidth
        $Chart1.Series["IopsRead"].IsVisibleInLegend = $true
        $Chart1.Series["IopsRead"].ChartArea = "ChartArea1"
        $Chart1.Series["IopsRead"].Legend = "Legend1"
        $Chart1.Series["IopsRead"].Color = [System.Drawing.Color]::RoyalBlue
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["IopsRead"].Points.addxy($Date, $_.IopsRead)
        }

        # data series
        [void]$Chart1.Series.Add("IopsWrite")
        $Chart1.Series["IopsWrite"].YAxisType = $AxisType::Primary
        $Chart1.Series["IopsWrite"].ChartType = "Line"
        $Chart1.Series["IopsWrite"].BorderWidth = $BorderWidth
        $Chart1.Series["IopsWrite"].IsVisibleInLegend = $true
        $Chart1.Series["IopsWrite"].ChartArea = "ChartArea1"
        $Chart1.Series["IopsWrite"].Legend = "Legend1"
        $Chart1.Series["IopsWrite"].Color = [System.Drawing.Color]::DarkTurquoise
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["IopsWrite"].Points.addxy($Date, $_.IopsWrite)
        }

        # data series
        [void]$Chart1.Series.Add("LatencyRead")
        $Chart1.Series["LatencyRead"].YAxisType = $AxisType::Primary
        $Chart1.Series["LatencyRead"].ChartType = "Line"
        $Chart1.Series["LatencyRead"].BorderWidth = $BorderWidth
        $Chart1.Series["LatencyRead"].IsVisibleInLegend = $true
        $Chart1.Series["LatencyRead"].ChartArea = "ChartArea1"
        $Chart1.Series["LatencyRead"].Legend = "Legend1"
        $Chart1.Series["LatencyRead"].Color = [System.Drawing.Color]::Green
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["LatencyRead"].Points.addxy($Date, $_.LatencyRead)
        }

        # data series
        [void]$Chart1.Series.Add("LatencyWrite")
        $Chart1.Series["LatencyWrite"].YAxisType = $AxisType::Primary
        $Chart1.Series["LatencyWrite"].ChartType = "Line"
        $Chart1.Series["LatencyWrite"].BorderWidth = $BorderWidth
        $Chart1.Series["LatencyWrite"].IsVisibleInLegend = $true
        $Chart1.Series["LatencyWrite"].ChartArea = "ChartArea1"
        $Chart1.Series["LatencyWrite"].Legend = "Legend1"
        $Chart1.Series["LatencyWrite"].Color = [System.Drawing.Color]::SpringGreen
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["LatencyWrite"].Points.addxy($Date, $_.LatencyWrite)
        }

        # data series
        [void]$Chart1.Series.Add("ThroughputRead")
        $Chart1.Series["ThroughputRead"].YAxisType = $AxisType::Secondary
        $Chart1.Series["ThroughputRead"].ChartType = "Line"
        $Chart1.Series["ThroughputRead"].BorderWidth = $BorderWidth
        $Chart1.Series["ThroughputRead"].IsVisibleInLegend = $true
        $Chart1.Series["ThroughputRead"].ChartArea = "ChartArea1"
        $Chart1.Series["ThroughputRead"].Legend = "Legend1"
        $Chart1.Series["ThroughputRead"].Color = [System.Drawing.Color]::Firebrick
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["ThroughputRead"].Points.addxy($Date, ($_.ThroughputRead / 1024 / 1024))
        }

        # data series
        [void]$Chart1.Series.Add("ThroughputWrite")
        $Chart1.Series["ThroughputWrite"].YAxisType = $AxisType::Secondary
        $Chart1.Series["ThroughputWrite"].ChartType = "Line"
        $Chart1.Series["ThroughputWrite"].BorderWidth = $BorderWidth
        $Chart1.Series["ThroughputWrite"].IsVisibleInLegend = $true
        $Chart1.Series["ThroughputWrite"].ChartArea = "ChartArea1"
        $Chart1.Series["ThroughputWrite"].Legend = "Legend1"
        $Chart1.Series["ThroughputWrite"].Color = [System.Drawing.Color]::OrangeRed
        $DataSource | ForEach-Object {
            $Date = ([datetime]::parse($_.Date, $Culture)).ToString('hh:mm:ss tt')
            [void]$Chart1.Series["ThroughputWrite"].Points.addxy($Date, ($_.ThroughputWrite / 1024 / 1024))
        }

        # save chart and send filename to the pipeline
        try {
            $Chart1.SaveImage("$Path\SVTmetric-$ShortName-$DateStamp.png", "png")
            Get-ChildItem "$Path\SVTmetric-$ShortName-$DateStamp.png"
        }
        catch {
            throw "Could not create $Path\SVTmetric-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SVTcapacity
function Get-SVTcapacityChart {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]$Capacity
    )

    if ($PSVersionTable.PSVersion.Major -gt 5) {
        throw "Microsoft Chart Controls are not currently supported with PowerShell Core, use Windows PowerShell"
    }
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    $Path = Get-Location
    $ChartLabelFont = 'Arial, 10pt'
    $ChartTitleFont = 'Arial, 13pt'
    $DateStamp = Get-Date -Format "yyMMddhhmmss"

    $objectlist = $Capacity.HostName | Select-Object -Unique
    foreach ($Instance in $ObjectList) {
        $Cap = $Capacity | Where-Object Hostname -eq $Instance | Select-Object -Last 1

        $DataSource = [ordered]@{
            'Allocated Capacity'          = $Cap.AllocatedCapacity / 1GB
            'Used Capacity'               = $Cap.UsedCapacity / 1GB
            'Used Logical Capacity'       = $Cap.UsedLogicalCapacity / 1GB
            'Free Space'                  = $Cap.FreeSpace / 1GB
            'Capacity Savings'            = $Cap.CapacitySavings / 1GB
            'Local Backup Capacity'       = $Cap.LocalBackupCapacity / 1GB
            'Remote Backup Capacity'      = $Cap.RemoteBackupCapacity / 1GB
            'Stored Compressed Data'      = $Cap.StoredCompressedData / 1GB
            'Stored Uncompressed Data'    = $Cap.StoredUncompressedData / 1GB
            'Stored Virtual Machine Data' = $Cap.StoredVirtualMachineData / 1GB
        }

        # chart object
        $Chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart

        $Chart1.Width = 1200
        $Chart1.Height = 600

        # title
        try {
            $ShortName = ([ipaddress]$Instance).IPAddressToString
        }
        catch {
            $ShortName = $Instance -split '\.' | Select-Object -First 1
        }
        [void]$Chart1.Titles.Add("HPE.SimpliVity.Host: $ShortName - Capacity from $($Cap.Date)")
        $Chart1.Titles[0].Font = "Arial,16pt"
        $Chart1.Titles[0].Alignment = "topLeft"

        # chart area
        $Area1 = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
        $Area3Dstyle = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea3DStyle
        $Area3Dstyle.Enable3D = $true
        $Area3Dstyle.LightStyle = 1
        $Area3Dstyle.Inclination = 20
        $Area3Dstyle.Perspective = 0

        $Area1 = $Chart1.ChartAreas.Add('ChartArea1')
        $Area1.Area3DStyle = $Area3Dstyle

        $Area1.AxisY.Title = "Size (GB)"
        $Area1.AxisY.TitleFont = $ChartTitleFont
        $Area1.AxisY.LabelStyle.Font = $ChartLabelFont
        $Area1.AxisX.MajorGrid.Enabled = $false
        $Area1.AxisX.MajorTickMark.Enabled = $true
        $Area1.AxisX.LabelStyle.Enabled = $true

        $Max = $DataSource.Values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
        if ($Max -lt 10000) {
            $Area1.AxisY.Interval = 500
        }
        Elseif ($Max -lt 20000) {
            $Area1.AxisY.Interval = 1000
        }
        Else {
            $Area1.AxisY.Interval = 5000
        }
        $Area1.AxisX.Interval = 1
        $Chart1.ChartAreas["ChartArea1"].AxisY.LabelStyle.Angle = 0
        $Chart1.ChartAreas["ChartArea1"].AxisX.LabelStyle.Angle = -45

        # add series
        [void]$Chart1.Series.Add("Data")
        $Chart1.Series["Data"].Points.DataBindXY($DataSource.Keys, $DataSource.Values)

        # save chart
        try {
            $Chart1.SaveImage("$Path\SVTcapacity-$ShortName-$DateStamp.png", "png")
            Get-ChildItem "$Path\SVTcapacity-$ShortName-$DateStamp.png"
        }
        catch {
            throw "Could not create $Path\SVTcapacity-$ShortName-$DateStamp.png"
        }
    }
}

# Helper function for Get-SVTdisk
# Notes: This method works quite well when all the disks are the same capacity. The 380 H introduces a bit
# of a problem. As long as the disks are sorted by slot number (i.e. the first disk will always be an SSD), 
# then the 380H disk capacity will be 1.92TB - the first disk is used to confirm. This method may break if 
# additional models continue to be added.
function Get-SVTmodel { 
    $ModelNumer = ('325','325','2600','380','380','380','380','380','380 Gen10 H','380','380')
    $DiskCount = (4,6,6,5,5,9,12,12,12,4,6)
    $DiskCapacity = (2,2,2,1,2,2,2,4,2,2,2)
    $Kit = ('4-8TB - SVT325 Extra Small',
        '7-15TB - SVT325 Small',
        '7-15TB - SVT2600',
        '3-6TB - SVT380Gen10 Extra Small',
        '6-12TB - SVT380Gen10 Small',
        '12-25TB - SVT380Gen10 Medium',
        '20-40TB - SVT380Gen10 Large',
        '40-80TB - SVT380Gen10 Extra Large',
        '20-50TB - SVT380Gen10H',           #4X1.92 SSD + 8X4TB HDD
        '8-16TB - SVT380Gen10G 4X1.92TB',
        '7-15TB - SVT380Gen10G 6X.192TB'
    )
    
    0..7 | foreach-object {
        [PSCustomObject]@{
            ModelNumber = $ModelNumer[$_]
            DiskCount = $DiskCount[$_]
            DiskCapacity = $DiskCapacity[$_]
            StorageKit = $Kit[$_]
        }
    }
}

#endregion Utility

#region Backup

<#
.SYNOPSIS
    Display information about HPE SimpliVity backups.
.DESCRIPTION
    Show backup information from the HPE SimpliVity Federation. By default SimpliVity backups from the last 24 hours are
    shown, but this can be overridden by specifying the -Hour parameter. Alternatively, specify VM name, Cluster name,
    or Datacenter name (with or without -Hour) to filter backups appropriately.

    You can use the -Latest parameter to display (one of) the latest backups for each VM. (Be careful, a policy may have more than one rule
    to backup to different detinations - only one of the backups is shown).

    Use the -Limit parameter to limit the number of backups shown. There is a known issue where setting the limit above 3000 can result in out of
    memory errors, so the -Limit parameter can currently be set between 1 and 3000. The recommended default of 500 is used. A warning is displayed
    if the number of backups in the environment exceeds the limit for a specific Get-SVTbackup command.

    Verbose is automatically turned on to show more information about what this command is doing.
.PARAMETER VMname
    Show backups for the specified virtual machine only.
.PARAMETER DataStoreName
    Show backups from the specified Simplivity datastore only.
.PARAMETER ClusterName
    Show backups from the specified HPE SimpliVity cluster only.
.PARAMETER BackupName
    Show backups from the specified backup name.
.PARAMETER All
    Show all backups. The maximum limit of 3000 is assumed, so this command might take a while depending on the number of backups in the environment.
.PARAMETER Latest
    Show (one of) the latest backup for every unique virtual machine.
.PARAMETER Hour
    The number of hours preceeding to report on. By default, the last 24 hours of backups are shown.
.EXAMPLE
    PS C:\> Get-SVTbackup

    Show the last 24 hours of backups from the SimpliVity Federation
.EXAMPLE
    PS C:\> Get-SVTbackup -Hour 48 | Select-Object VMname, DataStoreName, SentMB, UniqueSizeMB | Format-Table -Autosize

    Show backups up to 48 hours old and select specific properties to display
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName '2019-05-05T00:00:00-04:00'

    Shows the backup(s) with the specified backup name
.EXAMPLE
    PS C:\> Get-SVTbackup -All

    Shows all backups. This might take a while to complete (Limit is set to 3000, overriding a specified Limit)
.EXAMPLE
    PS C:\> Get-SVTbackup -Latest

    Show the last backup for every VM.
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname MyVM

    Shows backups in the last 24 hours for the specified VM only.
.EXAMPLE
    PS C:\> Get-SVTbackup -Datastore MyDatastore

    Shows all backups on the specified datastore.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Backup
.NOTES
Known issues with the REST API Get operations for Backup objects:
OMNI-53190 REST API Limit recommendation for REST GET backup object calls
OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints
#>
function Get-SVTbackup {
    [CmdletBinding(DefaultParameterSetName = 'ByHour')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVMName')]
        [System.String]$VMName,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByDatastoreName')]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByClusterName')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByBackupName')]
        [Alias("Name")]
        [System.String]$BackupName,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'AllBackup')]
        [switch]$All,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVMName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByHour')]
        [System.String]$Hour,

        [Parameter(Mandatory = $false, ParameterSetName = 'ByVMName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByDatastoreName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClusterName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'AllBackup')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByHour')]
        [switch]$Latest,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3000)]   # There is a known performance issue with /backups API. HPE recommends 500 default, 3000 maximum (OMNI-53190)
        [Int]$Limit = 500
    )

    $VerbosePreference = 'Continue'

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    # Display the date with the correct locale display date.
    # However, we want 2 digits with day, month and hour for date alignment - these adjustments don't fix all locales, but they don't break any either.
    $culture = (Get-Culture).DateTimeFormat
    $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
    $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
    $LocalFormat = "$LocalDate $LocalTime"

    $BackupObject = @()

    # $Hour is used to filter via API if no other property is specified.
    if ($Hour) {
        $StartDate = (Get-Date).AddHours(-$Hour)
        $DisplayHour = $Hour
    }
    else {
        $StartDate = (Get-Date).AddHours(-24)  # this is the default, if no other property is specified
        $DisplayHour = 24
    }

    # Offset is problematic with /backups API. Using 0 to avoid inconsistant results - If this is fixed in API, a parameter will be added"
    # Case sensitivity is promplematic with /backups API. Some properties do not support case insensitive filter, so assuming case sensitive for all - If this is fixed in API, revert to using case=insensitive
    $Uri = "$($global:SVTconnection.OVC)/api/backups?case=sensitive&offset=0"

    # Filter backup objects. the /backups API has known issue where you can only filter on 1 property (OMNI-46361). Using limit is ok.
    if ($VMname) {
            Write-Verbose "VM names are currently case sensitive"
            $Uri += "&limit=$Limit&virtual_machine_name=$VMname"
    }
    elseif ($DatastoreName) {
            Write-Verbose "Datastore names are currently case sensitive"
            $Uri += "&limit=$Limit&datastore_name=$DatastoreName"
    }
    elseif ($ClusterName) {
            Write-Verbose "Cluster names are currently case sensitive"
            $Uri += "&limit=$Limit&omnistack_cluster_name=$ClusterName"
    }
    elseif ($BackupName) {
            Write-Verbose "Backup names are currently case sensitive"
            $BackupName = "$BackupName*"
            $Uri += "&limit=$Limit&name=$($BackupName -replace '\+', '%2B')"
    }
    elseif ($All) {
        # Bypass filtering by $Hour, or by the default 24 hours
        Write-Verbose "Assuming maximum recommended limit of 3000 with the -All parameter. This command may take a long time to complete"
        $Limit=3000
        $Uri += "&limit=$Limit"
    }
    else {
        # If no other parameters are specified, show the last 24 hours by default, or by a specified hour range.
        $UniversalDate = $StartDate.ToUniversalTime()
        $CreatedAfter = "$(Get-Date $UniversalDate -format s)Z"
        $Uri += "&limit=$Limit&created_after=$CreatedAfter"
        Write-Verbose "Displaying backups from the last $DisplayHour hours, (created after $(Get-date $StartDate -Format $LocalFormat)), limited to $limit backups"
    }


    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    # API response contains a useful count. Note that this doesn't always reflect the truth (when trying to filter using multiple properties)
    $BackupCount = $Response.count
    If ($backupCount -gt $Limit) {
        Write-Warning "There are $BackupCount matching backups, but limited to displaying only $Limit. Either increase -Limit or use more restrictive parameters"
    }
    else {
        Write-Verbose "There are $BackupCount matching backups"
    }

    $Response.backups | ForEach-Object {
        if ($_.created_at -as [datetime]) {
            $CreateDate = Get-Date -Date $_.created_at -Format $LocalFormat
        }
        else {
            $CreateDate = $null
        }
        if ($_.unique_size_timestamp -as [DateTime]) {
            $UniqueSizeDate = Get-Date -Date $_.unique_size_timestamp -Format $LocalFormat
        }
        else {
            $UniqueSizeDate = $null
        }

        if ($_.expiration_time -as [Datetime]) {
            $ExpirationDate = Get-Date -Date $_.expiration_time -Format $LocalFormat
        }
        else {
            $ExpirationDate = $null
        }

        $CustomObject = [PSCustomObject]@{
            PSTypeName       = 'HPE.SimpliVity.Backup'
            VMname           = $_.virtual_machine_name
            CreateDate       = $CreateDate
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

    # If $Hour was specified with some other parameter, filter here. If by itself (or no parameters), we've already filtered via the /backups API.
    If (($VMName -or $DatastoreName -or $ClusterName -or $BackupName) -and $Hour) {

        Write-Verbose "The -Hour parameter was specified with another parameter, show only the backups newer than $(Get-date $StartDate -Format $LocalFormat)"
        $BackupObject = $BackupObject | Where-Object {$(Get-Date $_.CreateDate) -gt $StartDate}
    }

    # Finally, if -Latest was specified, just display the lastest backup of each VM
    # (or more correctly, ONE of the latest - its possible to have 2 rules in a policy to backup a VM to 2 destinations at once).
    if ($Latest) {
        Write-Verbose "The -Latest parameter was specified, show only the latest backup of each VM from the requested backups"
        $BackupObject | 
            ForEach-Object { $_.CreateDate = [datetime]::ParseExact($_.CreateDate, $LocalFormat, $null); $_} |
            Group-Object VMname |
            ForEach-Object {$_.Group | Sort-Object CreateDate | Select-Object -Last 1}
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
#>
function New-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname,

        [Parameter(Mandatory = $false, Position = 1)]
        [Alias("DestinationName")]
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
    }

    process {
        foreach ($VM in $VMname) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in the begin block might be a
                # problem on systems with a large number of VMs.
                $VMobj = Get-SVTvm -VMname $VM -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            if ($ClusterName) {
                try {
                    $DestinationId = Get-SVTcluster -ClusterName $ClusterName | Select-Object -ExpandProperty ClusterId
                }
                catch {
                    throw $_.Exception.Message
                }
            }
            else {
                # No destination cluster specified, so use the cluster id local the VM being backed up
                $DestinationId = $VMobj.ClusterId
            }

            if ($AppConsistent) {
                $ApplicationConsistant = $True
            }
            else {
                $ApplicationConsistant = $False
            }

            $Body = @{'backup_name' = $BackupName
                'destination_id'    = $DestinationId
                'app_consistent'    = $ApplicationConsistant
                'consistency_type'  = $ConsistencyType
                'retention'         = $RetentionDay * 1440  # must be specified in minutes
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VMobj.VmId + '/backup'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
.PARAMETER RestoreToOriginal
    Specifies that the existing virtual machine is overwritten
.PARAMETER BackupId
    The UID of the backup(s) to restore from
.PARAMETER VMname
    The virtual machine name(s)
.PARAMETER DatastoreName
    The destination datastore name
.EXAMPLE
    PS C:\> Get-SVTbackup -BackupName 2019-05-09T22:00:01-04:00 | Restore-SVTvm -RestoreToOriginal

    Restores the virtual machine(s) in the specified backup to the original VM name(s)
.EXAMPLE
    PS C:\> Get-SVTbackup -VMname MyVM | Sort-Object CreateDate | Select-Object -Last 1 | Restore-SVTvm

    Restores the latest backup of specified virtual machine, giving it the name of the original VM with a data stamp appended
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Restore-SVTvm {
    # Elected to call this 'restore VM' rather than 'restore backup' as per the API, because it makes more sense
    [CmdletBinding(DefaultParameterSetName = 'RestoreToOriginal')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'RestoreToOriginal')]
        [switch]$RestoreToOriginal,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelinebyPropertyName = $true, ParameterSetName = 'NewVM')]
        [System.String]$VMname,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true, ParameterSetName = 'NewVM')]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }
        $AllDataStore = Get-SVTdatastore
    }
    process {
        foreach ($BkpId in $BackupId) {
            if ($RestoreToOriginal) {
                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/restore?restore_original=true'
            }
            else {
                try {
                    $DataStoreId = $AllDataStore | Where-Object DataStoreName -eq $DataStoreName | Select-Object -ExpandProperty DataStoreId
                }
                catch {
                    throw $_.Exception.Message
                }

                if ($VMname.Length -gt 59) {
                    $RestoreVMname = "$($VMname.Substring(0,59))-restore-$(Get-Date -Format 'yyMMddhhmmss')"
                }
                else {
                    $RestoreVMname = "$VMname-restore-$(Get-Date -Format 'yyMMddhhmmss')"
                }

                $Body = @{
                    'datastore_id'         = $DataStoreId
                    'virtual_machine_name' = $RestoreVMname
                } | ConvertTo-Json
                Write-Verbose $body

                $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/restore?restore_original=false'
            }

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
    PS C:\> Get-Backup -BackupName 2019-05-09T22:00:01-04:00 | Remove-SVTbackup

    Deletes the backups with the specified backup name
.EXAMPLE
    PS C:\> Get-Backup -VMname MyVM -Hour 3 | Remove-SVTbackup

    Deletes any backup that's at least 3 hours old for the specified virtual machine
.EXAMPLE
    PS C:\> Get-Backup | ? VMname -match "test" | Remove-SVTbackup

    Deletes all backups for all virtual machines that have "test" in their name
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This cmdlet uses the /api/backups/delete REST API POST call which creates a task to delete the specified backup. This call can accept
    multiple backup IDs, but its used here to delete one backup Id at a time. This also works for backups in remote clusters.

    There is another specific DELETE call (/api/backups/<bkpId>) which works locally (i.e. if you're connected to an OVC where the backup
    resides), but this fails when trying to delete remote backups.
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
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/delete'

            $Body = @{
                'backup_id' = @($BkpId)
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
        }
    }

    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Stops (cancels) a currently executing HPE SimpliVity backup
.DESCRIPTION
    Stops (cancels) a currently executing HPE SimpliVity backup

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\>Get-SVTbackup -BackupName '2019-05-12T01:00:00-04:00' | Stop-SVTBackup

    Cancels the specified backup
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/cancel'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                write-warning "task = $Task"
                throw $_.Exception.Message
            }
            [array]$AllTask += $Task
            $Task
        }
    }

    end {
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Copy HPE SimpliVity backups to another cluster
.DESCRIPTION
    Copy HPE SimpliVity backups to another cluster

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\>Get-SVTbackup -Hour 2 | Copy-SVTbackup -ClusterName Production

    Copy the last two hours of backups to the specified cluster.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Copy-SVTbackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [alias("DestinationName")]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }

        $ClusterId = Get-SVTcluster | Where-Object ClusterName -eq $ClusterName | Select-Object -ExpandProperty ClusterId
    }

    process {
        foreach ($thisbackup in $BackupId) {
            $Body = @{
                'destination_id' = $ClusterId
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $thisbackup + '/copy'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
    }
}

<#
.SYNOPSIS
    Locks HPE SimpliVity backups to prevent them from expiring
.DESCRIPTION
    Locks HPE SimpliVity backups to prevent them from expiring

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.EXAMPLE
    PS C:\>Get-SVTBackup -BackupName 2019-05-09T22:00:01-04:00 | Lock-SVTbackup
    PS C:\>Get-SVTtask

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
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/lock'

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
    }
}

<#
.SYNOPSIS
    Rename existing HPE SimpliVity backup(s)
.DESCRIPTION
    Rename existing HPE SimpliVity backup(s).

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.PARAMETER BackupName
    The new backup name. Must be a new unique name. The command fails if there are existing backups with this name.
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
        [Alias("Name")]
        [System.String]$BackupName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }
    }

    process {
        foreach ($BkpId in $BackupId) {
            $Body = @{
                'backup_name' = $BackupName
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/backups/' + $BkpId + '/rename'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
    PS C:\> Get-Backup -BackupName 2019-05-09T22:00:01-04:00 | Set-SVTbackupRetention -RetentionDay 21

    Gets the backups with the specified name and sets the retention to 21 days.
.INPUTS
    System.String
    HPE.SimpliVity.Backup
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Set-SVTbackupRetention {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Int]$RetentionDay,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$BackupId

        # Force is supported by the API - it tells SimpliVity to set the retention even if backups will be expired.
        # This currently doesn't work, see help. For now, this parameter is disabled so if you try to decrease the retention for
        # a backup policy where backups will be expired, you'll receive an error in the task.
        #[Parameter(Mandatory=$true, Position=2)]
        #[Switch]$Force
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
        }

        if ($Force) {
            Write-Warning 'Possible deletion of some backups, depending on age and retention set'
            $ForceRetention = $true
        }
        else {
            $ForceRetention = $false
        }
    }

    process {
        # This API call accepts a list of backup Ids. However, we are creating a task per backup ID here.
        # Using a task list with a single task may be more efficient, but its inconsistent with the other cmdlets.
        foreach ($BkpId in $BackupId) {
            $Body = @{
                'backup_id' = @($BkpId)            # Expects an array (when converted to Json, its surrounded with square brackets)
                'retention' = $RetentionDay * 1440 # Must be specified in minutes
                'force'     = $ForceRetention
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/backups/set_retention'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
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
    }
}

<#
.SYNOPSIS
    Calculate the unique size of HPE SimpliVity backups
.DESCRIPTION
    Calculate the unique size of HPE SimpliVity backups

    BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes
    using this command a little cumbersome by itself. However, you can use Get-SVTBackup to identify the backups you want to target
    and then pipe the output to this command.
.PARAMETER BackupId
    Use Get-SVTbackup to output the required VMs as input for this command
.EXAMPLE
    PS C:\>Get-SVTbackup -VMname VM01 | Update-SVTbackupUniqueSize

    Starts a task to calculate the unique size of the specified backup(s)
.EXAMPLE
    PS:\> Get-SVTbackup -Latest | Update-SVTbackupUniqueSize

    Starts a task per backup object to calculate the unique size of the latest backup for each local VM.
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    This command only updates the backups in the local cluster. Login to an OVC in a remote cluster to update the backups there
    The UniqueSizeDate property is updated on the backup object(s) when you run this command
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
            'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
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

    Writes the specified datastore information into a CSV file
.EXAMPLE
    PS C:\> Get-SVTdatastore | Select-Object Name, SizeGB, Policy

    Shows the specified properties for the HPE SimpliVity datastore object(s).
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.DataStore
.NOTES
#>
function Get-SVTdatastore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Name")]
        [System.String]$DatastoreName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    #Get OmniStack Datastores in Federation
    $Uri = $global:SVTconnection.OVC + '/api/datastores?show_optional_fields=true&case=insensitive'

    if ($DatastoreName) {
        $Uri += '&name=' + $DatastoreName
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $culture = (Get-Culture).DateTimeFormat
    $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
    $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
    $LocalFormat = "$LocalDate $LocalTime"

    $Response.datastores | ForEach-Object {
        if ($_.created_at -as [datetime]) {
            $CreateDate = Get-Date -Date $_.created_at -Format $LocalFormat
        }
        else {
            $CreateDate = $null
        }
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.DataStore'
            PolicyId                 = $_.policy_id
            MountDirectory           = $_.mount_directory
            CreateDate               = $CreateDate
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
            HypervisorFreeSpaceGB    = "{0:n0}" -f ($_.hypervisor_free_space / 1gb)
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
        [Alias("Name")]
        [System.String]$DatastoreName,

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("DestinationName")]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateRange(1, 1048576)]   # Max is 1024TB (matches the SimpliVity plugin limit)
        [int]$SizeGB
    )

    try {
        $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
        $PolicyID = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId -Unique
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
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'name'                 = $DataStoreName
        'omnistack_cluster_id' = $ClusterId
        'policy_id'            = $PolicyId
        'size'                 = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/datastores/'

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
    Removes the specified SimpliVity datastore. The datastore cannot be in use by any virtual machines.
.PARAMETER Datastore
    Specify the datastore to delete
.EXAMPLE
    PS C:\>Remove-SVTdatastore -Datastore DStemp
    PS C:\>Get-SVTtask

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
        [Alias("Name")]
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
    }

    $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId

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
        [Alias("Name")]
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
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'size' = $SizeGB * 1Gb # Size must be in bytes
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/resize'

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
    Sets/changes the backup policy on a HPE SimpliVity Datastore
.DESCRIPTION
    A SimpliVity datastore must have a backup policy assigned to it. A default backup policy
    is assigned when a datastore is created. This command allows you to change the backup
    policy for the specifed datastore
.PARAMETER DatastoreName
    Apply to specified datastore
.PARAMETER PolicyName
    The new backup policy for the specified datastore
.EXAMPLE
    PS C:\>Set-SVTdatastorePolicy -DatastoreName ds01 -PolicyName Weekly

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

    try {
        $DatastoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($DatastoreId) -or -not ($PolicyId)) {
        throw 'Specified datastore or policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'policy_id' = $PolicyId
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/set_policy'

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
    Adds a share to a HPE SimpliVity datastore for a compute node (a standard ESXi host)
.DESCRIPTION
    Adds a share to a HPE SimpliVity datastore for a specified compute node
.PARAMETER DatastoreName
    The datastore to add a new share to
.PARAMETER ComputeNodeName
    The compute node that will have the new share
.EXAMPLE
    PS C:\>Publish-SVTdatastore -DatastoreName DS01 -ComputeNodeName ESXi03

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
        [Alias("Name")]
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
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/share'

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
    Removes a share from a HPE SimpliVity datastore for a compute node (a standard ESXi host)
.DESCRIPTION
    Removes a share from a HPE SimpliVity datastore for a specified compute node
.PARAMETER DatastoreName
    The datastore to remove a share from
.PARAMETER ComputeNodeName
    The compute node that will no longer have access
.EXAMPLE
    PS C:\>Unpublish-SVTdatastore -DatastoreName DS01 -ComputeNodeName ESXi01

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
        [Alias("Name")]
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
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/unshare'

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
    Displays the ESXi compute nodes (standard ESXi hosts) that have access to the specified datastore(s)
.DESCRIPTION
    Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS
.PARAMETER DatastoreName
    Specify the datastore to display information for
.EXAMPLE
    PS C:\>Get-SVTdatastoreComputeNode -DatastoreName DS01

    Display the compute nodes that have NFS access to the specified datastore
.EXAMPLE
    PS C:\>Get-SVTdatastoreComputeNode

    Displays all datastores in the Federation and the compute nodes that have NFS access to them
.INPUTS
    system.string
    HPE.SimpliVity.Datastore
.OUTPUTS
    HPE.SimpliVity.ComputeNode
.NOTES
    This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V
#>
function Get-SVTdatastoreComputeNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$DatastoreName = (Get-SVTdatastore | Select-Object -ExpandProperty DatastoreName)
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }
    }

    process {
        foreach ($ThisDatastore in $DatastoreName) {
            try {
                $DatastoreId = Get-SVTdatastore -DatastoreName $ThisDatastore -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
            }
            catch {
                throw $_.Exception.Message
            }

            if (-not ($DatastoreId)) {
                throw 'Specified datastore name not found'
            }

            $Uri = $global:SVTconnection.OVC + '/api/datastores/' + $DatastoreId + '/standard_hosts'

            try {
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
                    VMCount            = $_.virtual_machine_count
                }
            }
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
#>
function Get-SVThost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Name")]
        [System.String]$HostName,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$ClusterName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    #Get OmniStack Hosts in Federation
    $Uri = $global:SVTconnection.OVC + '/api/hosts?show_optional_fields=true&case=insensitive'

    if ($HostName) {
        $Uri += '&name=' + $HostName
    }
    if ($ClusterName) {
        $Uri += '&compute_cluster_name=' + $ClusterName
    }

    # get hosts
    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $culture = (Get-Culture).DateTimeFormat
    $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
    $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
    $LocalFormat = "$LocalDate $LocalTime"
    
    $Response.hosts | Foreach-Object {
        if ($_.date -as [datetime]) {
            $Date = Get-Date -Date $_.date -Format $LocalFormat
        }
        else {
            $Date = $null
        }
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.Host'
            PolicyEnabled            = $_.policy_enabled
            ClusterId                = $_.omnistack_cluster_id
            StorageMask              = $_.storage_mask
            PotentialFeatureLevel    = $_.potential_feature_level
            Type                     = $_.type
            CurrentFeatureLevel      = $_.current_feature_level
            HypervisorId             = $_.hypervisor_object_id
            ClusterName              = $_.compute_cluster_name
            ManagementIP             = $_.management_ip
            FederationIP             = $_.federation_ip
            VirtualControllerName    = $_.virtual_controller_name
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
            HypervisorClusterId      = $_.compute_cluster_hypervisor_object_id
            Date                     = $Date
            UsedLogicalCapacityGB    = "{0:n0}" -f ($_.used_logical_capacity / 1gb)
            UsedCapacityGB           = "{0:n0}" -f ($_.used_capacity / 1gb)
            CompressionRatio         = $_.compression_ratio
            StoredUnCompressedDataGB = "{0:n0}" -f ($_.stored_uncompressed_data / 1gb)
            StoredCompressedDataGB   = "{0:n0}" -f ($_.stored_compressed_data / 1gb)
            EfficiencyRatio          = $_.efficiency_ratio
            DeduplicationRatio       = $_.deduplication_ratio
            LocalBackupCapacityGB    = "{0:n0}" -f ($_.local_backup_capacity / 1gb)
            CapacitySavingsGB        = "{0:n0}" -f ($_.capacity_savings / 1gb)
            AllocatedCapacityGB      = "{0:n0}" -f ($_.allocated_capacity / 1gb)
            StoredVMdataGB           = "{0:n0}" -f ($_.stored_virtual_machine_data / 1gb)
            RemoteBackupCapacityGB   = "{0:n0}" -f ($_.remote_backup_capacity / 1gb)
            FreeSpaceGB              = "{0:n0}" -f ($_.free_space / 1gb)
        }
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
    PS C:\> Get-SVThardware -HostName Host01 | Select-Object -ExpandProperty LogicalDrives

    Enumerates all of the logical drives from the specified host
.EXAMPLE
    PS C:\> (Get-SVThardware -HostName Host01).RaidCard

    Enumerate all of the RAID cards from the specified host, using dot notation
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
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }

        $Allhost = Get-SVThost
        if (-not $HostName) {
            $HostName = $AllHost | Select-Object -ExpandProperty HostName
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
            } #end foreach-object
        } # end foreach
    } # end process
}

function Get-SVTdisk {
[CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName
    )

    begin {
        $Hardware = Get-SVThardware
        if (-not $HostName) {
            $HostName = $Hardware.Hostname
        }
    }

    process {
        foreach ($Thishost in $HostName) {
            $HostHardware = $Hardware | Where-Object HostName -eq $Thishost
            
            # We MUST sort by slot, to ensure SSDs are at the top (380 H)
            $Disk = $HostHardware.logicaldrives.drive_sets.physical_drives | 
                Sort-Object {[int]($_.Slot -replace '(\d+).*', '$1')} |
                Get-Unique -AsString
            
            $DiskCapacity = [math]::Round(($Disk | Select-Object -First 1).capacity / 1TB)
            $DiskCount = ($Disk | Measure-Object).Count
            
            $SVTmodel = Get-SVTmodel | Where-Object {
                $HostHardware.ModelNumber -match $_.ModelNumber -and
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
                    PSTypeName       = 'HPE.SimpliVity.Disk'
                    SerialNumber     = $_.serial_number
                    Manufacturer     = $_.manufacturer
                    ModelNumber      = $_.model_number
                    Firmware         = $_.firmware_revision
                    Status           = $_.status
                    Health           = $_.health
                    Enclosure        = $_.enclosure
                    Slot             = $_.slot
                    CapacityTB       = "{0:n2}" -f ($_.capacity / 1000000000000)
                    WWN              = $_.wwn
                    PercentRebuilt   = $_.percent_rebuilt
                    AddtionalStatus  = $_.additional_status
                    MediaType        = $_.media_type
                    DrivePosition    = $_.drive_position
                    HostStorageKit   = $Kit
                    Hostname         = $ThisHost
                }
            } 
        } #end foreach
    } #end process
}

<#
.SYNOPSIS
    Display capacity information for the specified SimpliVity node
.DESCRIPTION
    Displays capacity information for a number of useful metrics, such as
    Free space, used capacity, compression ratio and efficiency ration over time
    for a specified SimpliVity node.
.PARAMETER Hostname
    The SimpliVity node you want to show capacity information for
.PARAMETER OffsetHour
    Offset in hours from now.
.PARAMETER Hour
    The range in hours (the duration from the specified point in time)
.PARAMETER Resolution
    The resolution in seconds, minutes, hours or days
.EXAMPLE
    PS C:\>Get-SVTcapacity -HostName MyHost

    Shows capacity information for the specified host for the last 24 hours
.EXAMPLE
    PS C:\>Get-SVTcapacity -HostName MyHost -Hour 1 -resolution MINUTE

    Shows capacity information for the specified host showing every minute for the last hour
.EXAMPLE
    PS C:\>Get-SVTcapacity -Chart

    Creates a chart for each host in the SimpliVity federation showing the latest capacity details
.INPUTS
    system.string
    HPESimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.Capacity
.NOTES
#>
function Get-SVTcapacity {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [string[]]$HostName,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$OffsetHour = 0,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Hour = 24,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SECOND', 'MINUTE', 'HOUR', 'DAY')]
        [System.String]$Resolution = 'HOUR',

        [Parameter(Mandatory = $false)]
        [switch]$Chart
    )

    begin {
        $VerbosePreference = 'Continue'
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
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
        $Allhost = Get-SVThost
        if (-not $HostName) {
            $HostName = $Allhost | Select-Object -ExpandProperty HostName
        }

        $culture = (Get-Culture).DateTimeFormat
        $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
        $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
        $LocalFormat = "$LocalDate $LocalTime"
    }

    process {
        foreach ($Thishost in $Hostname) {
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
                $MetricName = ($_.name -split '_' | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_) }) -join ''
                $_.data_points | ForEach-Object {
                    if ($_.date -as [DateTime]) {
                        $Date = Get-Date -Date $_.date -Format $LocalFormat
                    }
                    else {
                        $Date = $null
                    }
                    [pscustomobject] @{
                        Name  = $MetricName
                        Date  = $Date
                        Value = $_.value
                    }
                }
            }

            # Transpose the custom object to return each date with the value for each metric
            $CapacityObject = $CustomObject | Sort-Object -Property Date | Group-Object -Property Date | ForEach-Object {
                $Property = [ordered]@{
                    PStypeName = 'HPE.SimpliVity.Capacity'
                    Date       = $_.Name
                }
                $_.Group | Foreach-object {
                    if ($_.Name -match "Ratio") {
                        $Property += @{
                            "$($_.Name)" = "{0:n2}" -f $_.Value
                        }
                    }
                    Else {
                        $Property += @{
                            "$($_.Name)" = $_.Value
                        }
                    }
                }
                $Property += @{ HostName = $Thishost }
                New-Object -TypeName PSObject -Property $Property
            }

            if ($Chart) {
                $ChartObject += $CapacityObject
            }
            else {
                $CapacityObject
            }
        }
    }

    end {
        if ($Chart) {
            Get-SVTcapacityChart -Capacity $ChartObject
        }
    }
}

<#
.SYNOPSIS
    Removes a HPE SimpliVity node from the cluster/federation
.DESCRIPTION
    Removes a HPE SimpliVity node from the cluster/federation. Once this command is executed, the specified node must
    be factory reset and can then be redeployed using the Deployment Manager. This command is equivilent GUI command
    "Remove from federation"

    If there are any virtual machines running on the node or if the node is not HA-compliant, this command will fail. You can
    specify the force command, but we aware that this could cause data loss.
.PARAMETER HostName
    Specify the node to remove.
.PARAMETER Force
    Forces removal of the node from the HPE SimpliVity federation. THIS CAN CAUSE DATA LOSS. If there is one node left in the cluster, this
    parameter must be specified (removes HA compliance for any VMs in the affected cluster.)
.EXAMPLE
    PS C:\>Remove-SVThost -HostName Host01

    Removes the node from the federation providing there are no VMs running and providing the node is HA-compliant.
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Remove-SVThost {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript( { $_ -in (Get-SVThost).HostName })]
        [Alias("Name")]
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
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $HostId + '/remove_from_federation'

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
    Shutdown a HPE Omnistack Virtual Controller
.DESCRIPTION
     Ideally, you should only run this command when all the VMs in the cluster
     have been shutdown, or if you intend to leave virtual controllers running in the cluster.

     This RESTAPI call only works if executed on the local host to the virtual controller. So this command
     connects to the virtual controller on the specifed host to shut it down.

     Note: Once the shutdown is executed on the specified host, this command will reconnect to another operational
     virtual controller in the Federation, using the same credentials, if there is one.
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName <Name of SimpliVity host>

    if not the last operational virtual controller, this command waits for the affected VMs to be HA compliant. If it
    is the last virtual controller, the shutdown does not wait for HA compliance.

    You will be prompted before the shutdown. If this is the last virtual controller, ensure all virtual machines are powered off,
    otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName Host01 -Confirm:$false

    Shutdown the specified virtual controller without confirmation. If this is the last virtual controller, ensure all virtual
    machines are powered off, otherwise there may be loss of data.
.EXAMPLE
    PS C:\> Start-SVTshutdown -HostName Host01 -Whatif -Verbose

    Reports on the shutdown operation, including connecting to the virtual controller, without actually performing the shutdown.
.INPUTS
    System.String
.OUTPUTS
    System.Management.Automation.PSCustomObject
.NOTES
#>
function Start-SVTshutdown {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByHostName')]
        [System.String]$HostName
    )

    $VerbosePreference = 'Continue'
    try {
        $AllHost = Get-SVThost -ErrorAction Stop
        $ThisHost = $AllHost | Where-Object HostName -eq $HostName
        $NextHost = $AllHost | Where-Object {$_.HostName -ne $HostName -and $_.State -eq 'ALIVE'} | Select-Object -First 1 # so we can reconnect afterwards
        $ThisCluster = $ThisHost | Select-Object -First 1 -ExpandProperty Clustername

        $LiveHost = $Allhost | Where-Object {$_.ClusterName -eq $ThisCluster -and $_.State -eq 'ALIVE'} | Measure-Object | Select-Object -ExpandProperty Count

        $AllHost | Where-Object ClusterName -eq $ThisCluster | ForEach-Object {
            Write-Verbose "Current state of host $($_.Hostname) in cluster $ThisCluster is $($_.State)" 
        }
    }
    catch {
        throw $_.Exception.Message
    }

    # Exit if the virtual controller is already off
    if($ThisHost.State -ne 'ALIVE') {
        throw "The HPE Omnistack Virtual Controller on $($ThisHost.Hostname) is not running"
    } 


    if ($nexthost) {
        Write-Verbose "This command will reconnect to $($nexthost.Hostname) following the shutdown of the virtual controller on $($ThisHost.Hostname)"
    }
    else {
        Write-Verbose "This is the last operational HPE Omnistack Virtual Controller in the federation, reconnect not possible"
    }

 
    # Connect to the target virtual controller, using the existing credentials saved to $SVTconnection
    try {
        Write-Verbose "Connecting to $($ThisHost.VirtualControllerName) on host $($ThisHost.Hostname)..."
        Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential | Out-Null
        Write-Verbose "Successfully connected to $($ThisHost.VirtualControllerName) on host $($ThisHost.Hostname)"
    }
    catch {
        throw $_.Exception.Message
    }

    $Body = @{'ha_wait' = $true } | ConvertTo-Json      
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/json'
    }
    $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + '/shutdown_virtual_controller'
    Write-Verbose $Body

    # Confirm if this is the last running virtual controller in this cluster
    Write-Verbose "$LiveHost operational HPE Omnistack virtual controller(s) in the $ThisCluster cluster"
    If ($LiveHost -lt 2) {
        Write-Warning "This is the last Omnistack virtual controller running in the $ThisCluster cluster"
        Write-Warning "Using this command with confirm turned off could result in loss of data if you have not already powered off all virtual machines"
    }

    # Only execute the command if confirmed. Using -Whatif will report only
    if ($PSCmdlet.ShouldProcess("$($ThisHost.Hostname)","Shutdown virtual controller in cluster $ThisCluster")) {
        try {
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        if ($LiveHost -lt 2) {
            Write-Verbose 'Sleeping 10 seconds before issuing final shutdown...'
            Start-Sleep -Seconds 10

            # Instruct the shutdown task running on the last virtual controller in the cluster not to wait for HA compliance
            $Body = @{'ha_wait' = $false } | ConvertTo-Json
            Write-Verbose $Body
            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            Write-Output "Shutting down the last virtual controller in the $ThisCluster cluster now ($($ThisHost.Hostname))"  
        }
        

        if ($nexthost) {
            try {
                Write-Verbose "Reconnecting to $($nexthost.VirtualControllerName) on $($nexthost.Hostname)..."
                Connect-SVT -OVC $nextHost.ManagementIP -Credential $SVTconnection.Credential | Out-Null
                Write-Verbose "Successfully reconnected to $($nexthost.VirtualControllerName) on $($nexthost.Hostname)"
                $OVCrunning=$true
                Write-Verbose "Wait to allow the storage IP to failover to an operational virtual controller. This may take a long time if the host is running virtual machines."
                do {
                    Write-verbose "Waiting 30 seconds, do not issue additional shutdown commands until this operation completes..."
                    Start-Sleep -Seconds 30
                    $OVCstate = Get-SVThost -HostName $($ThisHost.Hostname) | Select-Object -ExpandProperty State
                    if($OVCstate -eq "FAULTY") {
                        $OVCrunning=$false
                    }
                } while ($OVCrunning)

                Write-Output "Successfully shutdown the virtual controller on $($ThisHost.Hostname)"
            }
            catch {
                throw $_.Exception.Message
            }
        }
        else {
            Write-Verbose "This was the last operational HPE Omnistack Virtual Controller in the Federation, reconnect not possible"
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
#>
function Get-SVTshutdownStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String[]]$HostName = (Get-SVThost | Select-Object -ExpandProperty HostName),

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
        foreach ($ThisHostName in $Hostname) {
            $ThisHost = $allHosts | Where-Object Hostname -eq $ThisHostName

            try {
                Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential -ErrorAction Stop | Out-Null
                Write-Verbose $SVTconnection
            }
            catch {
                Write-Error "Error connecting to $($ThisHost.ManagementIP) (host $ThisHostName). Check that it is running"
                break
            }

            $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'                = 'application/json'
                'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
            }

            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + '/virtual_controller_shutdown_status'

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
            }
            catch {
                Write-Error "Error connecting to $($ThisHost.ManagementIP) (host $ThisHostName). Check that it is running"
                break
            }

            $Response.shutdown_status | ForEach-Object {
                [PSCustomObject]@{
                    HostName = $ThisHostName
                    VirtualControllerName = $ThisHost.ManagementName
                    VirtualControllerIP   = $ThisHost.ManagementIP
                    ShutdownStatus        = $_.Status
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Cancel the previous shutdown command for one or more OmniStack Virtual Controllers
.DESCRIPTION
    Cancels a previously executed shutdown request for one or more OmniStack Virtual Controllers

    This RESTAPI call only works if executed on the local OVC. So this cmdlet iterates through the specifed hosts
    and connects to each specified host to sequentially shutdown the local OVC.

    Note, once executed, you'll need to reconnect back to a surviving OVC, using Connect-SVT to continue
    using the HPE SimpliVity cmdlets.
.EXAMPLE
    PS C:\> Stop-SVTshutdown -Hostname Host01
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Alias("Name")]
        [System.String[]]$HostName
    )

    begin {
        # Get all the hosts in the Federation.
        # We will be cancelling shutdown for one or more OVC's; grab all host information before we start
        try {
            $allHosts = Get-SVThost -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }
    }

    process {
        foreach ($ThisHostName in $Hostname) {
            # grab this host object from the collection
            $ThisHost = $allHosts | Where-Object Hostname -eq $ThisHostName
            Write-Verbose $($ThisHost | Select-Object Hostname, HostId)

            # Now connect to this host, using the existing credentials saved to global variable
            Connect-SVT -OVC $ThisHost.ManagementIP -Credential $SVTconnection.Credential | Out-Null
            Write-Verbose $SVTconnection

            # cancel shutdown the OVC on this host
            $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
                'Accept'                = 'application/json'
                'Content-Type'          = 'application/json'
            }


            $Uri = $global:SVTconnection.OVC + '/api/hosts/' + $ThisHost.HostId + '/cancel_virtual_controller_shutdown'

            try {
                $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Response.cancellation_status | ForEach-Object {
                [PSCustomObject]@{
                    VirtualController = $ThisHost.ManagementIP
                    CancellationStatus = $_.Status
                }
            }
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
.PARAMETER ClusterName
    Show information about the specified cluster only
.EXAMPLE
    PS C:\>Get-SVTcluster

    Shows all clusters in the Federation
.EXAMPLE
    PS C:\>Get-SVTcluster -ClusterName Production

    Shows information about the specified cluster
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Cluster
.NOTES
#>
function Get-SVTcluster {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Name")]
        [System.String]$ClusterName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters?show_optional_fields=true&case=insensitive'

    if ($ClusterName) {
        $Uri += '&name=' + $ClusterName
    }

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.omnistack_clusters | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName               = 'HPE.SimpliVity.Cluster'
            DataCenterName           = $_.hypervisor_object_parent_name
            ArbiterConnected         = $_.arbiter_connected
            DataCenterId             = $_.hypervisor_object_parent_id
            Type                     = $_.type
            Version                  = $_.version
            HypervisorClusterId      = $_.hypervisor_object_id
            Members                  = $_.members
            ClusterName              = $_.name
            ArbiterIP                = $_.arbiter_address
            HypervisorType           = $_.hypervisor_type
            ClusterId                = $_.id
            HypervisorIP             = $_.hypervisor_management_system
            HypervisorName           = $_.hypervisor_management_system_name
            UsedLogicalCapacityGB    = "{0:n0}" -f ($_.used_logical_capacity / 1gb)
            UsedCapacityGB           = "{0:n0}" -f ($_.used_capacity / 1gb)
            CompressionRatio         = $_.compression_ratio
            StoredUnCompressedDataGB = "{0:n0}" -f ($_.stored_uncompressed_data / 1gb)
            StoredCompressedDataGB   = "{0:n0}" -f ($_.stored_compressed_data / 1gb)
            EfficiencyRatio          = $_.efficiency_ratio
            UpgradeTaskId            = $_.upgrade_task_id
            DeduplicationRatio       = $_.deduplication_ratio
            UpgradeState             = $_.upgrade_state
            LocalBackupCapacityGB    = "{0:n0}" -f ($_.local_backup_capacity / 1gb)
            ClusterGroupIds          = $_.cluster_group_ids
            TimeZone                 = $_.time_zone
            InfoSightRegistered      = $_.infosight_configuration.infosight_registered
            InfoSightEnabled         = $_.infosight_configuration.infosight_enabled
            InfoSightProxyURL        = $_.infosight_configuration.infosight_proxy_url
            ClusterFeatureLevel      = $_.cluster_feature_level
            CapacitySavingsGB        = "{0:n0}" -f ($_.capacity_savings / 1gb)
            AllocatedCapacityGB      = "{0:n0}" -f ($_.allocated_capacity / 1gb)
            StoredVMdataGB           = "{0:n0}" -f ($_.stored_virtual_machine_data / 1gb)
            RemoteBackupCapacityGB   = "{0:n0}" -f ($_.remote_backup_capacity / 1gb)
            FreeSpaceGB              = "{0:n0}" -f ($_.free_space / 1gb)
        }
    }
}

<#
.SYNOPSIS
    Display information about HPE SimpliVity cluster throughput
.DESCRIPTION
    Calculates the throughput between each pair of omnistack_clusters in the federation
.EXAMPLE
    PS C:\>Get-SVTthroughput

.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTthroughput {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/throughput'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $culture = (Get-Culture).DateTimeFormat
    $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
    $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
    $LocalFormat = "$LocalDate $LocalTime"

    $Response | ForEach-Object {
        if ($_.date -as [DateTime]) {
            $Date = Get-Date -Date $_.date -Format $LocalFormat
        }
        else {
            $Date = $null
        }
        [PSCustomObject]@{
            PSTypeName                       = 'HPE.SimpliVity.Throughput'
            Date                             = $Date
            DestinationClusterHypervisorId   = $_.destination_omnistack_cluster_hypervisor_object_parent_id
            DestinationClusterHypervisorName = $_.destination_omnistack_cluster_hypervisor_object_parent_name
            DestinationClusterId             = $_.destination_omnistack_cluster_id
            DestinationClusterName           = $_.destination_omnistack_cluster_name
            SourceClusterHypervisorId        = $_.source_omnistack_cluster_hypervisor_object_parent_id
            SourceClusterHypervisorName      = $_.source_omnistack_cluster_hypervisor_object_parent_name
            SourceClusterId                  = $_.source_omnistack_cluster_id
            SourceClusterName                = $_.source_omnistack_cluster_name
            ThroughputKBs                    = "{0:n2}" -f ($_.throughput / 1kb)
        }
    }
}

<#
.SYNOPSIS
    Displays the timezones that HPE SimpliVity supports
.DESCRIPTION
    Displays the timezones that HPE SimpliVity supports
.EXAMPLE
    PS C:\>Get-SVTtimezone

.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTtimezone {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/time_zone_list'

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
    Sets the timezone on a HPE SimpliVity cluster
.DESCRIPTION
    Sets the timezone on a HPE SimpliVity cluster

    Use 'Get-SVTtimezone' to see a list of valid timezones
    Use 'Get-SVTcluster | Select-Object TimeZone' to see the currently set timezone
.EXAMPLE
    PS C:\>Set-SVTtimezone -Cluster PROD -Timezone 'Australia/Sydney'

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
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'time_zone' = $TimeZone
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/set_time_zone'

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
    Displays information about other HPE SimpliVity clusters
.DESCRIPTION
    Displays information about other HPE SimpliVity clusters directly connected to the specified cluster
.PARAMETER ClusterName
    Specify a cluster name to display other clusters directly connected to it
.EXAMPLE
    PS C:\>Get-SVTclusterConnected -ClusterName Production

    Displays information about the clusters directly connected to the specified cluster
.INPUTS
    System.String
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTclusterConnected {
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
        throw 'specified cluster not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }


    $Uri = $global:SVTconnection.OVC + '/api/omnistack_clusters/' + $ClusterId + '/connected_clusters'

    try {
        $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Response.omnistack_clusters | ForEach-Object {
        [PSCustomObject]@{
            PSTypeName          = 'HPE.SimpliVity.ConnectedCluster'
            Clusterid           = $_.id
            ClusterName         = $_.name
            ClusterType         = $_.type
            ClusterMembers      = $_.members
            ArbiterConnected    = $_.arbiter_connected
            ArbiterIP           = $_.arbiter_address
            HypervisorClusterId = $_.hypervisor_object_id
            DataCenterId        = $_.hypervisor_object_parent_id
            DataCenterName      = $_.hypervisor_object_parent_name
            HyperVisorType      = $_.hypervisor_type
            HypervisorIP        = $_.hypervisor_management_system
            HypervisorName      = $_.hypervisor_management_system_name
            ClusterVersion      = $_.version
            ConnectedClusters   = $_.connected_clusters
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
    Shows the rules of all backup policies from the SimpliVity Federation
.PARAMETER PolicyName
    Display information about the specified backup policy only
.PARAMETER RuleNumber
    If a backup policy has multiple rules, more than object is displayed. Specify the rule number
    to display just that rule. This is useful when a rule needs to be edited or deleted.
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
#>
function Get-SVTpolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $false)]
        [int]$RuleNumber
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies?case=insensitive'

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
                if (-not $RuleNumber -or $RuleNumber -eq $_.number) {
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
    Create a new HPE SimpliVity backup policy
.DESCRIPTION
    Create a new, empty HPE SimpliVity backup policy.
    To create or replace rules for the new backup policy, use Set-SVTpolicyRule.
    To assign the new backup policy, use Set-SVTdatastorePolicy to assign it to a datastore,
    or Set-SVTvmPolicy to assign it to a virtual machine.
.PARAMETER PolicyName
    The new backup policy name to create
.EXAMPLE
    PS C:\>New-SVTpolicy -Policy Silver

    Creates a new blank backup policy. To create or replace rules for the new backup policy, use Set-SVTpolicyRule.
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
        [ValidateScript( { $_ -notin (Get-SVTpolicy).PolicyName })]
        [Alias("Name")]
        [System.String]$PolicyName
    )

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'name' = $PolicyName
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/'

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
    Create/Add/Replace rule to a HPE SimpliVity backup policy
.DESCRIPTION
    Create/Add/Replace rule to a HPE SimpliVity backup policy
.PARAMETER PolicyName
    The backup policy to add backup rules to
.PARAMETER WeekDay
    Specifies the Weekday(s) to run backup, e.g. "Mon", "Mon,Tue" or "Mon,Wed,Fri"
.PARAMETER MonthDay
    Specifies the day(s) of the month to run backup, e.g. 1 or 1,11,21
.PARAMETER LastDay
    Specifies the last day of the month to run a backup
.PARAMETER All
    Specifies every day to run backup
.PARAMETER ClusterName
    Specifies the destination HPE SimpliVity cluster name
.PARAMETER StartTime
    Specifies the start time (24 hour clock) to run backup, e.g. 22:00
.PARAMETER EndTime
    Specifies the start time (24 hour clock) to run backup, e.g. 00:00
.PARAMETER FrequencyMin
    Specifies the frequency, in minutes (how many times a day to run). Must be between 1 and 1440 minutes (24 hours).
.PARAMETER RetentionDay
    Specifies the retention, in days.
.PARAMETER AppConsistant
    If this switch is specified and if an appropriate consistancy type is specified (e.g. VSS) , this is true, otherwise its false
.PARAMETER ConsistancyType
    Must be one of 'NONE', 'DEFAULT', 'VSS', 'FAILEDVSS' or 'NOT_APPLICABLE'
.PARAMETER ReplaceRules
    If this switch is specified, all existing rules in the specified backup policy are removed and replaced with this new rule.
.EXAMPLE
    PS C:\>Set-SVTpolicyRule -PolicyName Silver -All -ClusterName ProductionCluster -ReplaceRules

    Replaces all existing backup policy rules with a new rule, backup everyday to the specified cluster, using the default
    start time (00:00), end time (00:00), Frequency (1440, or once per day), retention of 1 day and no application consistency.
.EXAMPLE
    PS C:\>Set-SVTpolicyRule -PolicyName Silver -Weekday Mon,Wed,Fri -ClusterName Cluster01 -RetentionDay 7

    Adds a new rule to the specified policy to run backups on the specified weekdays and retain backup for a week.
.EXAMPLE
    PS C:\>Set-SVTpolicyRule -PolicyName Silver -Last -ClusterName Prod -RetentionDay 30 -AppConsistent -ConsistencyType VSS

    Adds a new rule to the specified policy to run an application consistent backup on the last day of each month, retaining it for 1 month.
.INPUTS
    System.String
.OUTPUTS
    HPE.SipmliVity.Task
.NOTES
#>
function Set-SVTpolicyRule {
    [CmdletBinding(DefaultParameterSetName = 'ByAllDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByWeekday')]
        [array]$WeekDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByMonthDay')]
        [array]$MonthDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByLastDay')]
        [switch]$LastDay,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByAllDay')]
        [switch]$All,

        [Parameter(Mandatory = $false, Position = 2)]
        [Alias("DestinationName")]
        [System.String]$ClusterName = '', # Default is local

        [Parameter(Mandatory = $false, Position = 3)]
        [System.String]$StartTime = '00:00',

        [Parameter(Mandatory = $false, Position = 4)]
        [System.String]$EndTime = '00:00',

        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateRange(1, 1440)]
        [System.String]$FrequencyMin = 1440, # Default is once per day

        [Parameter(Mandatory = $false, Position = 6)]
        [int]$RetentionDay = 1,

        [Parameter(Mandatory = $false, Position = 7)]
        [switch]$AppConsistent,

        [Parameter(Mandatory = $false, Position = 8)]
        [ValidateSet('NONE', 'DEFAULT', 'VSS', 'FAILEDVSS', 'NOT_APPLICABLE')]
        [System.String]$ConsistencyType = 'NONE',

        [Parameter(Mandatory = $false, Position = 9)]
        [switch]$ReplaceRules
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId -Unique
        if ($ClusterName) {
            $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
        }
        else {
            $ClusterId = ''
        }
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($PolicyId)) {
        throw 'Specified policy name not found'
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

    if ($StartTime -notmatch '^[0-2][0-9]:[0-5][0-9]$') {
        throw "Start time invalid. It must be in the form 00:00 (24 hour time). e.g. -StartTime 06:00"
    }
    if ($EndTime -notmatch '^[0-2][0-9]:[0-5][0-9]$') {
        throw "End time invalid. It must be in the form 00:00 (24 hour time). e.g. -EndTime 23:30"
    }

    if ($AppConsistent) {
        $ApplicationConsistant = $true
    }
    else {
        $ApplicationConsistant = $false
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = [ordered]@{
        'destination_id'         = $ClusterId
        'frequency'              = $FrequencyMin
        'retention'              = $RetentionDay * 1440  # Retention is in minutes.
        'days'                   = $TargetDay
        'start_time'             = $StartTime
        'end_time'               = $EndTime
        'application_consistent' = $ApplicationConsistant
        'consistency_type'       = $ConsistencyType
    } | ConvertTo-Json

    $Body = "[$body]"
    Write-Verbose $Body

    # Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules'

    if ($ReplaceRules) {
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
}

<#
.SYNOPSIS
    Edits an existing HPE SimpliVity backup policy
.DESCRIPTION
    Edits an existing HPE SimpliVity backup policy. You must specify the policy name and the rule number
    to be replaced. This cmdlet is very similar to Set-SVTpolicyRule, except it replaces a rule rather than adding one.

    Rule numbers start from 0 and increment by 1. Use Get-SVTpolicy to identify the rule you want to replace
.EXAMPLE
    PS C:\>Update-SVTPolicyRule -Policy Gold -RuleNumber 2 -Weekday Mon,tue,wed,thu,fri -ClusterName Prod -StartTime 20:00 -EndTime 23:00

    Replaces rule number 2 in the specified policy with a new weekday policy. Uses default retention and frequency, both 1 day
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    There seems to be a bug, you cannot update rule 0 if there are other rules.
    You can use Set-SVTpolicyRule with the -ReplaceRules parameter to remove all rules and start again.
#>
function Update-SVTpolicyRule {
    [CmdletBinding(DefaultParameterSetName = 'ByAllDay')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$RuleNumber,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByWeekday')]
        [array]$WeekDay,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByMonthDay')]
        [array]$MonthDay,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByLastDay')]
        [switch]$LastDay,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByAllDay')]
        [switch]$All,

        [Parameter(Mandatory = $false, Position = 3)]
        [Alias("DestinationName")]
        [System.String]$ClusterName = '',

        [Parameter(Mandatory = $false, Position = 4)]
        [System.String]$StartTime = '00:00',

        [Parameter(Mandatory = $false, Position = 5)]
        [System.String]$EndTime = '00:00',

        [Parameter(Mandatory = $false, Position = 6)]
        [ValidateRange(1, 1440)]
        [System.String]$FrequencyMin = 1440, # Default is once per day

        [Parameter(Mandatory = $false, Position = 7)]
        [int]$RetentionDay = 1,

        [Parameter(Mandatory = $false, Position = 8)]
        [switch]$AppConsistent,

        [Parameter(Mandatory = $false, Position = 9)]
        [ValidateSet('NONE', 'DEFAULT', 'VSS', 'FAILEDVSS', 'NOT_APPLICABLE')]
        [System.String]$ConsistencyType = 'NONE'
    )

    try {
        $Policy = Get-SVTpolicy -PolicyName $PolicyName -RuleNumber $RuleNumber -ErrorAction Stop
        $PolicyId = $Policy | Select-Object -ExpandProperty PolicyId -Unique
        $RuleId = $Policy | Select-Object -ExpandProperty RuleId -Unique
        if ($ClusterName) {
            $ClusterId = Get-SVTcluster -ClusterName $ClusterName -ErrorAction Stop | Select-Object -ExpandProperty ClusterId
        }
        else {
            $ClusterId = ''
        }
    }
    catch {
        throw $_.Exception.Message
    }
    if (-not ($PolicyId)) {
        throw 'Specified policy name or Rule number not found. Use Get-SVTpolicy to determine rule number for the rule you want to edit'
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

    if ($StartTime -notmatch '^[0-2][0-9]:[0-5][0-9]$') {
        throw "Start time invalid. It must be in the form 00:00 (24 hour time). e.g. -StartTime 06:00"
    }
    if ($EndTime -notmatch '^[0-2][0-9]:[0-5][0-9]$') {
        throw "End time invalid. It must be in the form 00:00 (24 hour time). e.g. -EndTime 23:30"
    }

    if ($AppConsistent) {
        $ApplicationConsistant = $true
    }
    else {
        $ApplicationConsistant = $false
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = [ordered]@{
        'destination_id'         = $ClusterId
        'frequency'              = $FrequencyMin
        'retention'              = $RetentionDay * 1440  # Retention is in minutes.
        'days'                   = $TargetDay
        'start_time'             = $StartTime
        'end_time'               = $EndTime
        'application_consistent' = $ApplicationConsistant
        'consistency_type'       = $ConsistencyType
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules/' + $RuleId

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Put -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
}

<#
.SYNOPSIS
    Deletes a backup rule from an existing HPE SimpliVity backup policy
.DESCRIPTION
    Delete an existing rule from a HPE SimpliVity backup policy. You must specify the policy name and the rule number
    to be removed.

    Rule numbers start from 0 and increment by 1. Use Get-SVTpolicy to identify the rule you want to delete
.EXAMPLE
    PS C:\>Remove-SVTPolicyRule -Policy Gold -RuleNumber 2

    Removes rule number 2 in the specified backup policy
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
    There seems to be a bug, you cannot remove rule 0 if there are other rules.
    You can use Set-SVTpolicyRule with the -ReplaceRules parameter to remove all rules, or remove the other rules first.
#>
function Remove-SVTpolicyRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]$RuleNumber
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
        throw 'Specified policy name or Rule number not found. Use Get-SVTpolicy to determine rule number for the rule you want to edit'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rules/' + $RuleId

    try {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Delete -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
    $Task
    $global:SVTtask = $Task
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
    PS C:\>Get-SVTpolicy
    PS C:\>Rename-SVTpolicy -PolicyName Silver -NewPolicyName Gold

    The first command confirms the new policy name doesn't exist. The second command renames the backup policy as specified.
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
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript( { $_ -notin (Get-SVTpolicy).PolicyName })]
        [System.String]$NewPolicyName
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if (-not ($PolicyId)) {
        throw 'Specified policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'name' = $NewPolicyName
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/rename'

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
    Removes a HPE SimpliVity backup policy
.DESCRIPTION
    Removes a HPE SimpliVity backup policy, providing it is not in use be any datastores or virtual machines.
.PARAMETER PoliciyName
    The policy to delete
.EXAMPLE
    PS C:\> Get-SVTvm | Select VMname, PolicyName
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
        [Alias("Name")]
        [System.String]$PolicyName
    )

    try {
        $PolicyId = Get-SVTpolicy -PolicyName $PolicyName -ErrorAction Stop | Select-Object -ExpandProperty PolicyId -Unique
    }
    catch {
        throw $_.Exception.Message
    }

    if ($null -eq $PolicyId) {
        throw 'Specified policy not found'
    }

    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
    }

    # Confirm the the policy is not in use before deleting it. To do this, check both datastores and VMs
    $UriList = @(
        $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/virtual_machines'
        $global:SVTconnection.OVC + '/api/policies/' + $PolicyId + '/datastores'
    )
    [Bool]$ObjectFound = $false
    [String]$Message = ''
    Foreach ($Uri in $UriList) {
        $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
        if ($Task.datastores) {
            $Message += "There are $(($Task.datastores).Count) databases using backup policy $PolicyName. "
            $ObjectFound = $true
        }
        If ($Task.virtual_machines) {
            $Message += "There are $(($Task.virtual_machines).Count) virtual machines using backup policy $PolicyName. "
            $ObjectFound = $true
        }
    }
    if ($ObjectFound) {
        throw $Message + 'Cannot remove a backup policy that is still in use'
    }

    # Delete the policy
    $Uri = $global:SVTconnection.OVC + '/api/policies/' + $PolicyId
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
    Suspends the HPE SimpliVity backup policy for a host, a cluster or the federation
.DESCRIPTION
    Suspend the HPE SimpliVity backup policy for a host, a cluster or the federation
.PARAMETER ClusterName
    Apply to specified Clusternanme
.PARAMETER HostName
    Apply to specified hostname
.PARAMETER Federation
    Apply to federation
.EXAMPLE
    PS C:\>Suspend-SVTpolicy -Federation

    Suspends backup policies for the federation
.EXAMPLE
    PS C:\>Suspend-SVTpolicy -ClusterName Prod

    Suspend backup policies for the specified cluster
.EXAMPLE
    PS C:\>Suspend-SVTpolicy -HostName host01

    Suspend backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
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
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/suspend'

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
    Resumes the HPE SimpliVity backup policy for a host, a cluster or the federation
.DESCRIPTION
    Resumes the HPE SimpliVity backup policy for a host, a cluster or the federation
.PARAMETER ClusterName
    Apply to specified Clusternanme
.PARAMETER HostName
    Apply to specified hostname
.PARAMETER Federation
    Apply to federation
.EXAMPLE
    PS C:\>Resume-SVTpolicy -Federation

    Resumes backup policies for the federation
.EXAMPLE
    PS C:\>Resume-SVTpolicy -ClusterName Prod

    Resumes backup policies for the specified cluster
.EXAMPLE
    PS C:\>Resume-SVTpolicy -HostName host01

    Resumes backup policies for the specified host
.INPUTS
    System.String
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
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
        'Content-Type'          = 'application/vnd.simplivity.v1.7+json'
    }

    $Body = @{
        'target_object_type' = $TargetType
        'target_object_id'   = $TargetId
    } | ConvertTo-Json
    Write-Verbose $Body

    $Uri = $global:SVTconnection.OVC + '/api/policies/resume'

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
    Display a report showing information about HPE SimpliVity backup rates and limits
.DESCRIPTION
    Display a report showing information about HPE SimpliVity backup rates and limits
.EXAMPLE
    PS C:\>Get-SVTpolicyScheduleReport

.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTpolicyScheduleReport {
    $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
        'Accept'                = 'application/json'
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
    Display information about VMs running on HPE SimpliVity hosts/storage
.DESCRIPTION
    Display information about virtual machines running in the HPE SimpliVity Federation. Accepts
    parameters to limit the objects returned. Also accepts output from Get-SVThost as input.

    Verbose is automatically turned on to show more information about what this command is doing.
.PARAMETER VMname
    Display information for the specified virtual machine
.PARAMETER DatastoreName
    Display information for virtual machines on the specified datastore
.PARAMETER ClusterName
    Display information for virtual machines on the specified cluster
.PARAMETER Hostname
    Display information for virtual machines on the specified host
.PARAMETER State
    Display information for virtual machines with the specified state
.PARAMETER Limit
    The maximum number of virtual machines to display
.EXAMPLE
    PS C:\> Get-SVTvm

    Shows all virtual machines in the Federation with state "ALIVE"
.EXAMPLE
    PS C:\> Get-SVTvm -State ALL

    Shows all virtual machines in the Federation with any state. This shows virtual machines with removed
    and deleted states as well as alive.
.EXAMPLE
    PS C:\> Get-SVTvm -VMname MyVM | Out-GridView -Passthru | Export-CSV FilteredVMList.CSV

    Exports the specified VM information to Out-GridView to allow filtering and then exports
    this to a CSV
.EXAMPLE
    PS C:\> Get-SVThost | ? HostName -notmatch "DR" | Get-SVTvm | Select-Object Name, SizeGB, Policy, HAstatus

    Show the VMs from the host or hosts that do not have "DR" in their name. Show the selected properties only.
.INPUTS
    System.String
    HPE.SimpliVity.Host
.OUTPUTS
    HPE.SimpliVity.VirtualMachine
.NOTES
Known issues:
OMNI-69918 - GET calls for virtual machine objects may result in OutOfMemortError when exceeding 8000 objects
#>
function Get-SVTvm {
    [CmdletBinding(DefaultParameterSetName = 'ByVMname')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVMName')]
        [Alias("Name")]
        [System.String]$VMname,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ById')]
        [System.String]$Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $false, Position = 2)]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$HostName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("ALIVE", "DELETED", "REMOVED", "ALL")]
        [System.String]$State = "ALIVE",

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 5000)]   # HPE recommends 8000 maximum records to avoid out of memory errors (OMNI-69918)
        [Int]$Limit = 500
    )

    begin {
        # $VerbosePreference = 'Continue'

        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
        }

        if ($limit -le 500) {
            Write-Verbose "Limiting the number of VM objects to display to $Limit. This improves performance but some virtual machines may not be included"
        }
        else {
            Write-Verbose "You have chosen a limit of $Limit VM objects. This command may take a long time to complete"
        }

        # We want to add hostanme to the custom object, which is not provided by the API, so calaculate it
        $Allhost = Get-SVThost

        if ($HostName -and $State -ne "ALIVE") {
            Write-Verbose 'The state of ALIVE is assumed when using the -Hostname parameter'
            $State = "ALIVE"
        }

        $Uri = "$($global:SVTconnection.OVC)/api/virtual_machines?show_optional_fields=true&case=insensitive&offset=0&limit=$Limit"
    }

    process {
        if ($VMname) {
            $Uri += "&name=$VMname"
        }
        if ($Id) {
            $Uri += "&id=$Id"
        }
        if ($DataStoreName) {
            $Uri += "&datastore_name=$DataStoreName"
        }
        if ($ClusterName) {
            $Uri += "&omnistack_cluster_name=$ClusterName"
        }
        if ($HostName) {
            $HostId = $Allhost | Where-Object HostName -eq $HostName | Select-Object -ExpandProperty HostId
            $Uri += "&host_id=$HostId"
        }
        if ($State -and $State -ne "ALL") {      #No state is specified, so all are returned
            $Uri += "&state=$State"
        }

        try {
            $Response = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Method Get -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        $VMCount = $Response.count
        If ($VMCount -gt $Limit) {
            Write-Warning "There are $VMCount matching virtual machines, but limited to displaying only $Limit. Either increase -Limit or use more restrictive parameters"
        }
        else {
            # Write-Verbose "There are $VMCount matching virtual machines"
        }

        $culture = (Get-Culture).DateTimeFormat
        $LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/','dd/' -creplace '^M/','MM/' -creplace '/d/','/dd/'
        $LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm','HH:mm'
        $LocalFormat = "$LocalDate $LocalTime"

        $Response.virtual_machines | ForEach-Object {
            if ($_.created_at -as [datetime]) {
                $CreateDate = Get-Date -Date $_.created_at -Format $LocalFormat
            }
            else {
                $CreateDate = $null
            }
            if ($_.deleted_at -as [DateTime]) {
                $DeletedDate = Get-Date -Date $_.deleted_at -format $LocalFormat
            }
            else {
                $DeletedDate = $null
            }

            $HostName = $Allhost | Where-Object HostID -eq $_.host_id | Select-Object -ExpandProperty Hostname

            [PSCustomObject]@{
                PSTypeName               = 'HPE.SimpliVity.VirtualMachine'
                PolicyId                 = $_.policy_id
                CreateDate               = $CreateDate
                PolicyName               = $_.policy_name
                DataStoreName            = $_.datastore_name
                ClusterName              = $_.omnistack_cluster_name
                DeletedDate              = $DeletedDate
                AppAwareVmStatus         = $_.app_aware_vm_status
                HostName                 = $HostName
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
                HAstatus                 = $_.ha_status
                HAresyncProgress         = $_.ha_resynchronization_progress
                HypervisorVMpowerState   = $_.hypervisor_virtual_machine_power_state
            }

        } #foreach
    } #process
}

<#
.SYNOPSIS
    Display the primary and secondary replica locations for HPE SimpliVity virtual machines
.DESCRIPTION
    Display the primary and secondary replica locations for HPE SimpliVity virtual machines
.PARAMETER VMname
    Display information for the specified virtual machine
.PARAMETER DatastoreName
    Display information for virtual machines on the specified datastore
.PARAMETER ClusterName
    Display information for virtual machines on the specified cluster
.PARAMETER Hostname
    Display information for virtual machines on the specified host
.EXAMPLE
    PS C:\>Get-SVTvmReplicaSet

    Displays the primary and secondary locations for all virtual machine replica sets.
.INPUTS
    system.string
.OUTPUTS
    PSCustomObject
.NOTES
#>
function Get-SVTvmReplicaSet {
    [CmdletBinding(DefaultParameterSetName = 'ByVM')]
    param (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ByVM')]
        [System.String]$VMname,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ByDatastore')]
        [System.String]$DataStoreName,

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'ByCluster')]
        [System.String]$ClusterName,

        [Parameter(Mandatory = $true, Position = 3, ParameterSetName = 'ByHost')]
        [System.String]$HostName
    )

    begin {
        $Allhost = Get-SVThost

        if ($VMname) {
            $VMobj = Get-SVTvm -VMname $VMname
        }
        elseif ($DataStoreName) {
            $VMobj = Get-SVTvm -DataStoreName $DataStoreName
        }
        elseif ($ClusterName) {
            $VMobj = Get-SVTvm -ClusterName $ClusterName
        }
        elseif ($HostName) {
            $VMobj = Get-SVTvm -HostName $HostName
        }
        else {
            $VMobj = Get-SVTvm  # default is all VMs
        }
    }

    process {
        foreach ($VM in $VMobj) {
            $PrimaryId = $VM.ReplicaSet | Where-Object role -eq 'PRIMARY' | Select-Object -ExpandProperty id
            $SecondaryId = $VM.ReplicaSet | Where-Object role -eq 'SECONDARY' | Select-Object -ExpandProperty id
            $PrimaryHost = $Allhost | Where-Object HostId -eq $PrimaryId | Select-Object -ExpandProperty HostName
            $SecondaryHost = $Allhost | Where-Object HostId -eq $SecondaryId | Select-Object -ExpandProperty HostName
            [PSCustomObject]@{
                PSTypeName  = 'HPE.SimpliVity.ReplicaSet'
                VMname      = $VM.VMname
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
    Clone one or more Virtual Machines hosted on SimpliVity storage/hosts
.DESCRIPTION
     This cmdlet will clone a given VM or VMs up to 20 times. It accepts multiple
     SimpliVity Virtual Machine objects and will execute 4 clone operations
     simultaneously, waiting so that only maximum of 4 clones are executing at once.
.PARAMETER VMname
    Specify one or more VMs to clone
.PARAMETER NumberOfClones
    Specify the number of clones, 1 to 20.
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
    C:\PS>Get-SVTtask | Format-List *

    Clone the specified VM three times. The second command monitors the cloning task(s) as they execute.
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
        $VerbosePreference = 'Continue'

        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        if ($NumberOfClones -gt 1) {
            Write-Verbose "When cloning the same VM(s) multiple times using -NumberOfClones, clones are performed one at a time"
        }
        else {
            Write-Verbose "When cloning multiple VMs, a maximum of four clone tasks can run at a time"
        }

        try {
            $allVm = Get-SVTvm -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        if ($NumberOfClones -gt 1) {
            $AllowedTask = 1
        }
        else {
            $AllowedTask = 4
        }
    }
    process {
        foreach ($VM in $VMname) {
            # Note: Disable Cloning of clones. It gets too confusing to track.
            if ($VM -match "\-clone\-\d{12}$") {
                Write-Warning "Ignoring clone $VM. If you really want to clone this VM again, rename it (remove '-clone-<datestamp>')"
                continue
            }
            1..$NumberOfClones | ForEach-Object {
                # Note: SimpliVity RESTAPI limits the VMname to 80 characters. (vCenter 6.5+ supports 128)
                # Note: Using the same default suffix for clone names as the SimpliVity CLI command - svt-vm-clone. (i.e. '-clone-<datestamp>')
                $CloneName = "$(($allVm | Where-Object VMname -eq $VM).VMname)"   # Get the real VM name, ensures the right case
                if ($CloneName.Length -gt 61) {
                    $CloneName = "$($CloneName.Substring(0,61))-clone-$(Get-Date -Format 'yyMMddhhmmss')"
                }
                else {
                    $CloneName = "$CloneName-clone-$(Get-Date -Format 'yyMMddhhmmss')"
                }

                Write-Verbose "Creating clone $CloneName from $VM"
                $VmId = ($allVm | Where-Object VMname -eq $VM).VmId

                $Body = @{'virtual_machine_name' = $CloneName
                    'app_consistent'             = $AppConsistent
                    'consistency_type'           = $ConsistencyType.ToUpper()
                } | ConvertTo-Json
                Write-Verbose $Body

                $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VmId + '/clone'

                try {
                    $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
                }
                catch {
                    throw $_.Exception.Message
                }

                [array]$AllTask += $Task
                $Task

                # Rules are:
                # 1. If cloning the same VM, we will only do 1 at a time
                # 2. If cloning different VMs, we can only do 4 at a time, as per current recommendations
                while ($true) {
                    $ActiveTask = Get-SVTtask -Task $AllTask |
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
    Move an existing virtual machine from one HPE SimpliVity datastore to another
.DESCRIPTION
    Relocates the specified virtual machine(s) to a different datastore in the federation. The datastore can be
    in the same or a different datacenter. Consider the following when moving a vm:
        1. You must power off the OS guest before moving, otherwise the operation fails
        2. In its new location, make sure the moved VM(s) boots up after the local OVC and shuts down before it
        3. Any pre-move backups (local or remote) stay associated with the VM(s) after it/they moves. You can use these
           backups to restore the moved VM(s).
        4. HPE OmniStack only supports one move operation per VM at a time. You must wait for the task to complete before
           attempting to move the same VM again
        5. If moving VM(s) out of the current cluster, DRS rules (created by the Intelligent Workload Optimizer) will vMotion the moved VM(s)
           to the destination
.PARAMETER VMname
    The name(s) of the virtual machines you'd like to move
.PARAMETER DatastoreName
    The destination datastore
.EXAMPLE
    PS C:\>Move-SVTVM -VMname MyVM -Datastore DR-DS01

    Moves the specified VM to the specified datastore
.EXAMPLE
    PS C:\>"VM1", "VM2" | Move-SVTVM -Datastore DS03

    Moves the specified VMs to the specfiied datastore
.EXAMPLE
    PS C:\>Get-VM | Where-Object VMname -match "WEB" | Move-SVTVM -Datastore DS03
    PS C:\>Get-SVTtask

    Move VM(s) with "Web" in their name to the specified datastore. Use Get-SVTtask to monitor the progress of the move task(s)
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Alias("Name")]
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
            $DataStoreId = Get-SVTdatastore -DatastoreName $DatastoreName -ErrorAction Stop | Select-Object -ExpandProperty DatastoreId
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($DatastoreId)) {
            throw 'Specified datastore not found'
        }
    }
    process {
        foreach ($VM in $VMname) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in the begin block, like we're
                # doing with datastores, might be a problem on systems with a large number of VMs.
                $VMobj = Get-SVTvm -VMname $VM -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Body = @{'virtual_machine_name' = $VMObj.VMname
                'destination_datastore_id'   = $DatastoreId
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VMObj.VmId + '/move'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            [array]$AllTask += $Task
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
    Stop a virtual machine hosted on HPE SimpliVity storage
.DESCRIPTION
    Stop a virtual machine hosted on HPE SimpliVity storage

    Stopping VMs with this command is not recommended. The VM will be in a "crash consistant" state.
    This action may lead to data loss or data corruption.

    A better option is to use the VMware PowerCLI Stop-VMGuest cmdlet. This shuts down the Guest OS gracefully.

    Note: This command requires a specific version in the content-type passed to the REST API.
    Upgrades to SimpliVity may require the version to be adjusted.
.PARAMETER VMname
    The virtual manchine name to stop
.EXAMPLE
    PS C:\>Stop-SVTvm -VMname MyVM

    Stops the VM. Not recommended for production workloads
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Alias("Name")]
        [System.String]$VMname
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.11+json'
        }
    }

    process {
        foreach ($VM in $VMname) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in the begin block might be a
                # problem on systems with a large number of VMs.
                $VMobj = Get-SVTvm -VMname $VM -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VMobj.VmId + '/power_off'

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
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Start a virtual machine hosted on HPE SimpliVity storage
.DESCRIPTION
    Start a virtual machine hosted on HPE SimpliVity storage

    Note: This command requires a specific version in the content-type passed to the REST API.
    Upgrades to SimpliVity may require the version to be adjusted.
.PARAMETER VMname
    The virtual manchine name to start
.EXAMPLE
    PS C:\>Start-SVTvm -VMname MyVM

    Starts the VM
.EXAMPLE
    PS C:\>Get-SVTvm -ClusterName DR01 | Start-SVTvm -VMname MyVM

    Starts the VMs in the specified cluster
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [Alias("Name")]
        [System.String]$VMname
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.11+json'
        }

    }

    process {
        foreach ($VM in $VMname) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in the begin block might be a
                # problem on systems with a large number of VMs.
                $VMobj = Get-SVTvm -VMname $VM -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VMobj.VmId + '/power_on'

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
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

<#
.SYNOPSIS
    Sets a new HPE SimpliVity backup policy on a virtual machine
.DESCRIPTION
    Sets a new HPE SimpliVity backup policy on a virtual machine. When a VM is first created, it inherits the
    backup policy set on the datastore it is first created on. Use this command to explicitely reset the backup
    policy for a given VM.
.PARAMETER VMname
    The VM that will get a new backup policy setting
.PARAMETER PolicyName
    The name of the backup policy to be used
.EXAMPLE
    PS C:\>Get-SVTvm -Datastore DS01 | Set-SVTPolicy Silver

    Changes the backup policy for all VMs on the specified datastore.
.EXAMPLE
    Set-SVTPolicy Silver VM01

    Using positional parameters to apply a new backup policy to the VM
.EXAMPLE
    Set-SVTPolicy -VMname VM01 -PolicyName Silver

    Using named parameters to apply a new backup policy to the VM
.INPUTS
    System.String
    HPE.SimpliVity.VirtualMachine
.OUTPUTS
    HPE.SimpliVity.Task
.NOTES
#>
function Set-SVTvmPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [System.String]$PolicyName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
        [System.String]$VMname
    )

    begin {
        $Header = @{'Authorization' = "Bearer $($global:SVTconnection.Token)"
            'Accept'                = 'application/json'
            'Content-Type'          = 'application/vnd.simplivity.v1.1+json'
        }

        try {
            $PolicyId = Get-SVTpolicy -PolicyName $PolicyName | Select-Object -ExpandProperty PolicyId -Unique
        }
        catch {
            throw $_.Exception.Message
        }
        if (-not ($PolicyId)) {
            throw 'Specified policy name not found'
        }
    }
    process {
        foreach ($VM in $VMname) {
            try {
                # Getting a specific VM name within the loop here deliberately. Getting all VMs in the begin block might be a
                # problem on systems with a large number of VMs.
                $VMobj = Get-SVTvm -VMname $VM -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }

            $Body = @{
                'policy_id' = $PolicyId
            } | ConvertTo-Json
            Write-Verbose $Body

            $Uri = $global:SVTconnection.OVC + '/api/virtual_machines/' + $VMobj.VmId + '/set_policy'

            try {
                $Task = Invoke-SVTrestMethod -Uri $Uri -Header $Header -Body $Body -Method Post -ErrorAction Stop
            }
            catch {
                throw $_.Exception.Message
            }
            [array]$AllTask += $Task
            $Task
        }
    }
    end {
        # Useful to keep the task objects in this session, so we can keep track of them with Get-SVTtask
        $global:SVTtask = $AllTask
    }
}

#endregion VirtualMachine