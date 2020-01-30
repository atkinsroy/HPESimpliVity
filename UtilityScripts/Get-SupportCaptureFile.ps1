###########################################################################
# Get-SupportCaptureFile.ps1
# 
# Utility script that automates creation and download of the support file
# from one or more SimpliVity virtual controllers.
#
# This script depends on a third party module called Posh-SSH which
# allows you to enter username and password via a credential. This has
# the advantage of not having to upload an ssh public key to every OVC, but
# it is less secure.
# 
# I have a version that uses OpenSSH (available on Window 10 1809 and above)
# if a more secure approach is required.
#
# Roy Atkins, HPE Pointnext Services
###########################################################################
#
# Requirements - You need to install Posh-SSH
# PS:\> Install-Module Posh-SSH
#
# Get a list of OVCs to connect to. By default, an existing CSV file with 
# a list of IP addresses is assumed.
#
# Other ways:
# $OVC = @('192.168.1.1','192.168.2.1')
# $OVC = (Get-SVThost).ManagementIP
#
# or specify the -OVC parameter with a comma seperated list of IPs.
param (
    [object]$OVC = (Import-CSV -Path .\ovclist.csv | Select-Object -ExpandProperty OVC),
    [switch]$Silent,
    [switch]$Purge
)

if ($Silent) {
    # It is assumed you have previously created a credential file using, for example:
    # PS:\> Get-Credential -Message 'Enter password' -UserName 'administrator@vsphere.local' | Export-Clixml cred.xml
    $cred = Import-Clixml .\cred.xml
}
else {
    $cred = Get-Credential -Message 'Enter Password' -UserName 'administrator@vsphere.local'
}

$sshcapture = 'source /var/tmp/build/bin/appsetup; /var/tmp/build/cli/svt-support-capture'
$sshpurge = 'sudo find /core/capture/Capture*.tgz -maxdepth 1 -type f -exec rm -fv {} \;'
$sshfile = 'ls -pl /core/capture'

# Connect to each OVC
foreach ($controller in $OVC) {
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

# Run the capture on all the OVCs together - wait 7 minutes for the capture(s) to complete.
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

# Now we think we've got a capture file on each virtual controller. If the capture is not finished, there will still be 
# a folder, so wait until this is replaced with a capture file.
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
