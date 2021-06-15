#
# Inventory of SimpliVity Federation.
#
$PSDefaultParameterValues = @{'Export-Csv:NoTypeInformation' = $true }
'Clusters...' ; Get-SvtCluster | Export-Csv cluster.csv
'Hosts...' ; Get-SvtHost | Export-Csv host.csv
'Connected clusters...'
Get-SvtCluster | Select-Object -First 1 -ExpandProperty ClusterName | foreach-object { 
    Get-SvtClusterConnected -ClusterName $_ | 
    Export-csv clusterconnected.csv
}
'Datastores...' ; Get-SvtDatastore | Export-Csv datastore.csv
'Compute nodes...' ; Get-SvtDatastoreComputeNode | Export-Csv computenode.csv
'Hardware...' ; Get-SvtHardware | Export-Csv hardware.csv
'Disks...' ; Get-SvtDisk | Export-Csv disk.csv
'Policies...' ; Get-SvtPolicy | Export-Csv policy.csv
'Policy Schedule Report...' ; Get-SvtPolicyScheduleReport | Export-Csv policyschedulereport.csv
'Shutdown status of SVAs...' ; Get-SvtShutdownStatus | Export-Csv shutdownstatus.csv
'Version...' ; Get-SvtVersion | Export-Csv version.csv
'VMs...' ; Get-SvtVm | Export-Csv vm.csv
'VM replicas...' ; Get-SvtVmReplicaSet | Export-Csv replicas.csv
