---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# New-SVTbackup

## SYNOPSIS
Create one or more new HPE SimpliVity backups

## SYNTAX

```
New-SVTbackup [-VmName] <String> [[-DestinationName] <String>] [[-BackupName] <String>]
 [[-RetentionDay] <Int32>] [[-RetentionHour] <Int32>] [[-ConsistencyType] <String>] [<CommonParameters>]
```

## DESCRIPTION
Creates a backup of one or more virtual machines hosted on HPE SimpliVity. Either specify the VM names via the VmName parameter or use Get-SVTvm output to pass in the HPE SimpliVity VM objects to backup. Backups are directed to the specified destination cluster or external store, or to the local cluster for each VM if no destination name is specified.

## EXAMPLES

### EXAMPLE 1
```
New-SVTbackup -VmName MyVm -DestinationName ClusterDR
```

Backup the specified VM to the specified SimpliVity cluster, using the default backup name and retention

### EXAMPLE 2
```
New-SVTbackup MyVm StoreOnce-Data01 -RetentionDay 365 -ConsistencyType DEFAULT
```

Backup the specified VM to the specified external datastore, using the default backup name and retain the backup for 1 year. A consistency type of DEFAULT creates a VMware snapshot to quiesce the disk prior to taking the backup

### EXAMPLE 3
```
New-SVTbackup -BackupName "BeforeSQLupgrade" -VmName SQL01 -DestinationName SVTcluster -RetentionHour 2
```

Backup the specified SQL server with a backup name and a short (2 hour) retention

### EXAMPLE 4
```
Get-SVTvm | ? VmName -match '^DB' | New-SVTbackup -BackupName 'Manual backup prior to SQL upgrade'
```

Locally backup up all VMs with names starting with 'DB' using the specified backup name and with default 
retention of 1 day.

## PARAMETERS

### -VmName
The virtual machine(s) to backup.
Optionally use the output from Get-SVTvm to provide the required VM names.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -DestinationName
The destination cluster name or external store name. If nothing is specified, the virtual machine(s) is/are backed up locally. If there is a cluster with the same name as an external store, the cluster wins.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupName
Give the backup(s) a unique name, otherwise a default name with a date stamp is used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: "Created by $(($SVTconnection.Credential.Username -split '@')[0]) at " +
        "$(Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt')"
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionDay
Specifies the retention in days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionHour
Specifies the retention in hours.
This parameter takes precedence if RetentionDay is also specified.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConsistencyType
Available options are:
1.
NONE - This is the default and creates a crash consistent backup
2.
DEFAULT - Create application consistent backups using VMware Snapshot
3.
VSS - Create application consistent backups using Microsoft VSS in the guest operating system.
Refer 
   to the admin guide for requirements and supported applications

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: NONE
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.VirtualMachine
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
