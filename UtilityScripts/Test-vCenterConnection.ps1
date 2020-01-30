###########################################################################
# Test-vCenterConnection.ps1
# 
# Utility script that automates running netcat on all virtual controllers
# at once to verify connection to vCenter.
#
# This script depends on a third party module called Posh-SSH which
# allows you to enter username and password via a credential. This has
# the advantage of not having to upload an ssh public key to every OVC, but
# it is less secure.
#
# Roy Atkins, HPE Pointnext Services
###########################################################################
#
# Requirements - You need to install Posh-SSH
# PS:\> Install-Module Posh-SSH
#
# Get a list of OVCs to connect to. By default, an existing CSV file with 
# a list of IP addresses is assumed. Other ways:
#
# $OVC = @('192.168.1.1','192.168.2.1')
# $OVC = (Get-SVThost).ManagementIP
#
# or specify the -OVC parameter with a comma seperated list of IPs.
param (
    [object]$OVC = (Import-CSV -Path .\ovclist.csv | Select-Object -ExpandProperty OVC),
    [switch]$Silent,

    [string]$vCenter = '<Enter your Default vCenter IP address here>' 
)

if ($Silent) {
    # It is assumed you have previously created a credential file using, for example:
    # PS:\> Get-Credential -Message 'Enter password' -UserName 'administrator@vsphere.local' | Export-Clixml cred.xml
    $cred = Import-Clixml .\cred.xml
}
else {
    $cred = Get-Credential -Message 'Enter Password' -UserName 'administrator@vsphere.local'
}

# Start a transcript log
Start-Transcript -Path .\Test-vCenterConnection.log

# Enter commands to execute sequentially within each SSH session
$sshcommand = @(
    #"nc -zv $vCenter 9190"
    "nc -zv $vCenter 80"
    "nc -zv $vCenter 443"
)

# Connect to each OVC
"Connecting to specified virtual controllers..."
foreach ($controller in $OVC) {
    try {
        New-SSHSession -ComputerName $controller -port 22 -Credential $cred
    }
    catch {
        Write-Warning "Could not establish an SSH session to $controller"
    }
}

# Run the commands on all the OVCs together
"Executing each specified command on all specified virtual controllers..." 
try {
    $Session = Get-SSHsession
    foreach ($cmd in $sshcommand) {
        ("-" * 80) + "`nExecuting $cmd`n" + ("-" * 80)
        Invoke-SSHcommand -SessionId $Session.SessionId -Command $cmd -TimeOut 10 -ErrorAction Stop
    }
}
catch {
    Write-Warning $_.Exception.Message
}

# Cleanup
Stop-Transcript
$null = Remove-SSHSession -SessionId $Session.SessionId
