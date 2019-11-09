#
# Inventory of SimpliVity Federation.
#
$PSDefaultParameterValues = @{'Export-Csv:NoTypeInformation' = $true }
'Clusters...' ; Get-SVTcluster | Export-Csv cluster.csv
'Hosts...' ; Get-SVThost | Export-Csv host.csv
'Connected clusters...'
Get-SVTcluster | Select-Object -First 1 -ExpandProperty ClusterName | foreach-object { 
    Get-SVTclusterConnected -ClusterName $_ | 
        Export-csv clusterconnected.csv
}
'Datastores...' ; Get-SVTdatastore | Export-Csv datastore.csv
'Compute nodes...' ; Get-SVTdatastoreComputeNode | Export-Csv computenode.csv
'Hardware...' ; Get-SVThardware | Export-Csv hardware.csv
'Policies...' ; Get-SVTpolicy | Export-Csv policy.csv
'Policy Schedule Report...' ; Get-SVTpolicyScheduleReport | Export-Csv policyschedulereport.csv
'Shutdown status of OVCs...' ; Get-SVTshutdownStatus | Export-Csv shutdownstatus.csv
'Version...' ; Get-SVTversion | Export-Csv version.csv
'VMs...' ; Get-SVTvm | Export-Csv vm.csv
'VM replicas...' ; Get-SVTvmReplicaSet | Export-Csv replicas.csv