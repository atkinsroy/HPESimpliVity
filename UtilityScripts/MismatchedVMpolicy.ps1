# This script finds virtual machines hosted on SimpliVity storage that are using backup policies 
# different to the backup policy used by the datastore where they are located. This occurs if a VM
# has been moved between datastores; a new VM inherits the datastore backup policy initially. If it is 
# subsequently moved or if the policy is manually set on the VM, it may not use its datastore backup policy.

# To use this script, you need to install the HPESimpliVity PowerShell module and connect to an OmniStack 
# virtual controller (OVC) in your environment.

$AllDatastore = Get-SVTdatastore
Get-SVTvm | ForEach-Object {
    $CheckPolicy = ($AllDataStore | Where-Object DatastoreName -eq $_.DatastoreName).PolicyName
    If ($CheckPolicy -ne $_.PolicyName) {
        [pscustomobject]@{
            'Mismatched VM'    = $_.VMName
            'VM Policy'        = $_.PolicyName
            'Datastore Policy' = $CheckPolicy
        }
    }
}
