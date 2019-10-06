# This script finds virtual machines hosted on SimpliVity storage that are using backup policies 
# different to the backup policy used by the datastore where they are located. This occurs if a VM
# has been moved between datastores; a new VM inherits the datastore backup policy initially. If it is 
# subsequently moved or if the policy is manually set on the VM, it may not use its datastore backup policy.

# It is assumed you have previously created a credential file using something similar to:
#Get-Credential -Message 'Enter a password at prompt' -UserName 'administrator@vsphere.local' | Export-Clixml OVCcred.xml

# It is assumed you have previously installed the HPESimpliVity module from PS Gallery, using:
# Install-Module -Name HPESimpliVity -RequiredVersion 1.1.4

# Connect is an OmniStack Virtual Controller in your environment:
$IP = 192.168.1.1   # change this to match one of your virtual controllers
$Cred = Import-Clixml .\OVCcred.xml
Connect-SVT -OVC $IP -Credential $Cred

$AllDatastore = Get-SVTdatastore
Get-SVTvm | ForEach-Object {
    $CheckPolicy = ($AllDataStore | Where-Object DatastoreName -eq $_.DatastoreName).PolicyName
    If ($CheckPolicy -ne $_.PolicyName) {
        [pscustomobject]@{
            'Mismatched VM'    = $_.VMName
            'VM Policy'        = $_.PolicyName
            'DatastoreName'    = $_.DatastoreName
            'Datastore Policy' = $CheckPolicy
        }
    }
}
