#########################################################################
# Get-Support-File.ps1
# 
# Utility script that automates creation and download of the support file
# from one or more SimpliVity virtual controllers.
#
# Roy Atkins, HPE Pointnext Services
#########################################################################
#
# You need to create authentication key pair for SSH before you can connect to each virtual controller. 
# To do this, on the local system with PowerShell installed (Windows 10, Linux) enter the following 
# command in PowerShell:
#
# PS> cd ~
# Confirm if you have a .ssh folder in your home folder. If you do, maybe you already have a key pair which 
# you can use - there should be 2 files, id_rsa which is your private key, and id_rsa.pub, which is public key.
#
# If you don't have these files, or the .ssh folder is missing, create a new key pair, as follows:
#
# PS> ssh-keygen -r rsa -b 2048
# Accept all the defaults. You should now have the two files in the .ssh folder locally.
#
# Now you need to copy you public key to each virtual controller. We need to append the public
# key to an existing file that already has other public keys in it. To be safe, make a copy of the file first, copy
# the public key and then append it to the authoized_keys file for your admin account on the virtual controller:
# 
# PS> ssh administrator@vsphere.local@<OVC IP> 'cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys_saved'
# PS> scp .ssh\id_rsa.pub administrator@vsphere.local<OVC IP>:/tmp
# PS> ssh administrator@vsphere.local@<OVC IP> 'cat /tmp/id_rsa.pub >> ~/.ssh/authorized_keys'
#
# enter password after each command. After this, you should be able to connect over ssh without a password. Try something simple:
#
# PS> ssh administrator@vsphere.local@<OVC IP> 'cat /etc/hosts'
#
# If this works without prompting for a password, you're ready to run this script.

# Some variables
$sshcapture = 'source /var/tmp/build/bin/appsetup; /var/tmp/build/cli/svt-support-capture'
$sshfile = 'ls -pl /core/capture | grep -v /'

# Get a list of OVCs to connect to. You can use import-csv or other methods.
# $OVC = @('192.168.1.1','192.168.2.1')
# $OVC = (Get-SVThost).ManagementIP
$OVC = Import-Csv -Path .\ovclist.csv | Select-Object -ExpandProperty OVC

# Note: PowerShell V7 will support async execution using -Parallel and -Asjob on Foreach-Object cmdlet.
# Right now, we connect to each OVC one after the other.
foreach ($controller in $OVC) {
    try {
        "Connecting to $controller and running capture..."
        ssh "administrator@vsphere@$controller"  "$sshcapture"
    
        $CaptureFile = (ssh "administrator@vsphere@$controller" "$sshfile" | Select-Object -Last 1).Split(' ')[-1]
        $CaptureWeb = "http://$controller/capture/$CaptureFile"
    
        # Using the web method of download, because SimpliVity provides this. Using scp also works here.
        "Downloading the capture file: $CaptureWeb ..."
        Invoke-WebRequest -Uri $CaptureWeb -OutFile ".\$CaptureFile"
    }
    catch {
        Write-Warning "Something went wrong with the capture on virtual controller:$controller"
    }
}