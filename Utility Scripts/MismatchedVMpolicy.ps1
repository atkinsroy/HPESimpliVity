# Script to find VMs that are using backup policies different to their datastores' backup policy

$AllDatastore = Get-SVTdatastore
Get-SVTvm | ForEach-Object {
    $CheckPolicy = ($AllDataStore | Where-Object DatastoreName -eq $_.DatastoreName).PolicyName
    If ($CheckPolicy -ne $_.PolicyName) {
        [pscustomobject]@{
            'Mismatced VM' = $_.VMName
            'VM Policy' = $_.PolicyName
            'Datastore Policy' = $CheckPolicy
        }
    }
}
