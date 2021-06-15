##############################################################################
# Get-SupportCaptureFile.ps1
#
# Description:
#   This is a utility script that automates the creation and download of the 
#   support file from one or more SimpliVity virtual controllers.
# 
# 
#   Download:
#   https://github.com/atkinsroy/HPESimpliVity
#
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
    This is a utility script that automates the creation and download of the 
    support capture file from one or more HPE SimpliVity virtual controllers.
.DESCRIPTION
    This script will connect to one or more HPE SimpliVity virtual controllers and
    establish a persistent session. This then provides the ability to initiate the
    creation of the support capture file in parallel. Finally, the support files are
    downloaded locally from each virtual controller.

    This script requires direct SSH (port 22) and HTTPS (port 443) access to each 
    HPE SimpliVity virtual controller.

    This script depends on a third party module called Posh-SSH, which
    provides the ability to enter username and password via a credential to establish
    SSH sessions. This has the advantage of not having to upload an ssh public key to 
    every SVA, but it is less secure. It is assumed that the same credentials can be used
    for each virtual controller.
 
    Install the required Posh-SSH using the following command: 
    PS:\> Install-Module Posh-SSH
.PARAMETER VA
    Accepts one or more FQDN's or IP Addresses. By default the script
    will look for a CSV called .\SVAList.csv in the local folder. The file
    must contain a heading of "SVA" on the first line. FQDN's or IP addresses
    for each virtual controller must be entered one per line, with no commas.
.PARAMETER Silent
    Do not prompt for credentials. This is possible, if you have previously saved
    the appropriate credentials to a file called .\cred.xml, in the local folder
.PARAMETER Purge
    This parameter will delete any previous capture files found on the virtual 
    controller(s) prior to creating and downloading a new support capture file 

.EXAMPLE
    PS C:\> Install-Module Posh-SSH
    PS C:\> Get-Credential -Message 'Enter password' -UserName 'administrator@vsphere.local' | Export-Clixml cred.xml
    PS C:\> Get-SupportCaptureFile -VA 192.168.1.1 -Silent

    The first command installs the required PowerShell module called Posh-SSH from the
    PowerShell Gallery. 

    The second command creates a credential file so that the -Silent parameter can be used

    The the third command will connect over SSH with the specified virtual controller and 
    initiate a support capture. Finally the capture file is downloaded locally over HTTPS.
.EXAMPLE
    PS C:\> Get-SupportCaptureFile

    This command requires a file called .\SVAList.csv containing a list of virtual controllers
    to connect to. Because -Silent was not entered, you will be prompted enter credentials.
.EXAMPLE
    PS C:\> Get-SupportCaptureFile -VA '192.168.1.1','192.168.2.1' -Purge

    This command will connect to the two specified virtual controllers and delete any pre-existing
    support capture files before initiating a new capture.
.INPUTS
    System.PSobject
    System.String
.OUTPUTS
    System.String
.NOTES
    Tested with 3.7.9 and 3.7.10.
#>

param (
    [object]$VA = (Import-CSV -Path .\SVAList.csv | Select-Object -ExpandProperty VA),

    [switch]$Silent,

    [switch]$Purge
)

$sshcapture = 'source /var/tmp/build/bin/appsetup; /var/tmp/build/cli/svt-support-capture'
$sshpurge = 'sudo find /core/capture/Capture*.tgz -maxdepth 1 -type f -exec rm -fv {} \;'
$sshfile = 'ls -pl /core/capture'

if ($Silent) {
    # It is assumed you have previously created a credential file using, for example:
    try {
        $cred = Import-Clixml .\cred.xml -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }
}
else {
    $cred = Get-Credential -Message 'Enter Password' -UserName 'administrator@vsphere.local'
}

# Connect to each SVA
foreach ($controller in $VA) {
    try {
        New-SSHSession -ComputerName $controller -port 22 -Credential $cred -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not establish an SSH session to $controller"
    }
}

# Get all the SSH Sessions
$Session = Get-SSHsession

# If -Purge is specified, remove any old capture files...
If ($PSBoundParameters.ContainsKey('Purge')) {
    try {
        "Purging previous capture files..."
        Invoke-SSHcommand -SessionId $Session.SessionId -Command $sshpurge -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not purge old capture files on one or more virtual controllers"
    }
}

# Run the capture on all the SVAs together - wait 7 minutes for the capture(s) to complete.
# The capture(s) continue and complete regardless, but the ssh command may timeout. The Timeout
# parameter isn't really needed, as we check for completion later - but it does reduce the "wait..."
# messages generated later.
try {
    "Running capture command on each target virtual controller. This will take up to 7 minutes..."
    $null = Invoke-SSHcommand -SessionId $Session.SessionId -Command $sshcapture -TimeOut 420
}
catch {
    Write-Warning "Capture command timed out on one or more virtual controllers. We'll need to wait longer, it seems."
}

# Now we think we've got a capture file on each virtual controller. If the capture is not 
# finished, there will still be a folder, so wait until this is replaced with a capture file.
foreach ($ThisSession in $Session) {
    $ThisId = $ThisSession.SessionId
    $ThisHost = $ThisSession.Host
    $FolderFound = $true
    do {
        try {
            $Output = Invoke-SSHcommand -SessionId $ThisId -Command $sshfile | Select-Object -ExpandProperty Output
            $Output

            $CaptureFile = ($Output | Select-Object -last 1).Split(' ')[-1]
            "Capture file is $CaptureFile"
            # Check if the last object is a folder, if so wait.
            if (($CaptureFile[-1]) -eq '/') {
                "Wait 30 seconds for capture to complete on $ThisHost..."
                Start-Sleep 30
            }
            else {
                $FolderFound = $false
                $CaptureWeb = "http://$ThisHost/capture/$CaptureFile"
                "Downloading the capture file: $CaptureWeb ..."
                Invoke-WebRequest -Uri $CaptureWeb -OutFile ".\$CaptureFile"
            }
        }
        catch {
            $FolderFound = $false
            Write-Warning "Could not download the support file from $Thishost : $($_.Exception.Message)"
        }
    }
    While ($FolderFound)
}

# Cleanup
$null = Remove-SSHSession -SessionId $Session.SessionId
