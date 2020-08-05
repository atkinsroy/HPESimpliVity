---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Remove-SVTbackup

## SYNOPSIS
Delete one or more HPE SimpliVity backups

## SYNTAX

```
Remove-SVTbackup [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Deletes one or more backups hosted on HPE SimpliVity.
Use Get-SVTbackup output to pass in the backup(s) 
to delete or specify the Backup ID, if known.

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same name). 
This makes using this command a little cumbersome by itself.
However, you can use Get-SVTBackup to 
identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTBackup -BackupName 2019-05-09T22:00:01-04:00 | Remove-SVTbackup
```

Deletes the backups with the specified backup name.

### EXAMPLE 2
```
Get-SVTBackup -VmName MyVm -Hour 3 | Remove-SVTbackup
```

Delete any backup that is at least 3 hours old for the specified virtual machine

### EXAMPLE 3
```
Get-SVTBackup | ? VmName -match "test" | Remove-SVTbackup
```

Delete all backups for all virtual machines that have "test" in their name

### EXAMPLE 4
```
Get-SVTbackup -CreatedBefore 01/01/2020 -Limit 3000 | Remove-SVTbackup
```

This command will remove backups older than the specified date.

## PARAMETERS

### -BackupId
The UID of the backup(s) to delete

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Backup
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES
This cmdlet uses the /api/backups/delete REST API POST call which creates a task to delete the specified 
backup.
This call accepts multiple backup IDs, and efficiently removes multiple backups with a single task. 
This also works for backups in remote clusters.

There is another REST API DELETE call (/api/backups/\<bkpId\>) which only works locally (i.e.
when 
connected to an OVC where the backup resides), but this fails when trying to delete remote backups.

## RELATED LINKS
