---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Copy-SVTbackup

## SYNOPSIS
Copy HPE SimpliVity backups to another cluster or an external store

## SYNTAX

```
Copy-SVTbackup [-DestinationName] <String> [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Copy HPE SimpliVity backups between SimpliVity clusters and backups to and from external stores.

Note, backups currently on external stores can only be copied to the cluster they were backed 
up from.
A backup on an external store cannot be copied to another external store.

If you try to copy a backup to a destination where is already exists, the task will fail with a "Duplicate
name exists" message. 

BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). 
This makes using this command a little cumbersome by itself. However, you can use Get-SVTBackup to 
identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTbackup -VmName Server2016-01 | Copy-SVTbackup -DestinationName Cluster02
```

Copy the last 24 hours of backups for the specified VM to the specified SimpliVity cluster

### EXAMPLE 2
```
Get-SVTbackup -Hour 2 | Copy-SVTbackup Cluster02
```

Copy the last two hours of all backups to the specified cluster

### EXAMPLE 3
```
Get-SVTbackup -Name 'BeforeSQLupgrade' | Copy-SVTbackup -DestinationName StoreOnce-Data02
```

Copy backups with the specified name to the specified external store.

## PARAMETERS

### -DestinationName
Specify the destination SimpliVity Cluster name or external store name.
If a cluster exists with the
same name as an external store, the cluster wins.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupId
Specify the Backup ID(s) to copy.
Use the output from an appropriate Get-SVTbackup command to provide
one or more Backup ID's to copy.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Backup
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
