# 
# Create a new Manifest for HPE SimpliVity Module
#

New-ModuleManifest -Path '.\HPESimpliVity.psd1' `
    -RootModule '.\HPESimpliVity.psm1' `
    -FormatsToProcess '.\HPESimpliVity.Backup.Format.ps1xml', `
    '.\HPESimpliVity.DataStore.Format.ps1xml', `
    '.\HPESimpliVity.Host.Format.ps1xml', `
    '.\HPESimpliVity.Cluster.Format.ps1xml', `
    '.\HPESimpliVity.Policy.Format.ps1xml', `
    '.\HPESimpliVity.VM.Format.ps1xml', `
    '.\HPESimpliVity.Task.Format.ps1xml' `
    -Author 'Roy Atkins' `
    -CompanyName 'Hewlett Packard Enterprise' `
    -ModuleVersion 1.1.0 `
    -FunctionsToExport Connect-SVT, Copy-SVTbackup, Get-SVTbackup, Get-SVTcapacity, Get-SVTcluster, `
    Get-SVTclusterConnected, Get-SVTdatastore, Get-SVTdatastoreComputeNode, Get-SVThardware, Get-SVThost, `
    Get-SVTmetric, Get-SVTovcShutdownStatus, Get-SVTpolicy, Get-SVTpolicyScheduleReport, Get-SVTtask, `
    Get-SVTthroughput, Get-SVTtimezone, Get-SVTversion, Get-SVTvm, Get-SVTvmReplicaSet, Lock-SVTbackup, `
    Move-SVTvm, New-SVTbackup, New-SVTclone, New-SVTdatastore, New-SVTpolicy, Publish-SVTdatastore, `
    Remove-SVTbackup, Remove-SVTdatastore, Remove-SVThost, Remove-SVTpolicy, Rename-SVTbackup, `
    Rename-SVTpolicy, Resize-SVTdatastore, Restore-SVTvm, Resume-SVTpolicy, Set-SVTbackupRetention, `
    Set-SVTdatastorePolicy, Set-SVTpolicyRule, Set-SVTtimezone, Set-SVTvmPolicy, Start-SVTvm, `
    Stop-SVTbackup, Stop-SVTovc, Stop-SVTvm, Suspend-SVTpolicy, Undo-SVTovcShutdown, Unpublish-SVTdatastore, `
    Update-SVTbackupUniqueSize, Update-SVTpolicyRule, Remove-SVTpolicyRule `
    -Description 'HPE SimpliVity PowerShell Module that utilises the REST API' `
    -Copyright '(c) 2019 Hewlett Packard Enterprise. All rights reserved.' `
    -PowerShellVersion 3.0