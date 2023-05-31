---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtBackup.md
schema: 2.0.0
---

# Remove-SvtBackup

## SYNOPSIS
Delete one or more HPE SimpliVity backups

## SYNTAX

```
Remove-SvtBackup [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Deletes one or more backups hosted on HPE SimpliVity.
Use Get-SvtBackup output to pass in the backup(s)
to delete or specify the Backup ID, if known.

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same name).
This makes using this command a little cumbersome by itself.
However, you can use Get-SvtBackup to
identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtBackup -BackupName 2019-05-09T22:00:01-04:00 | Remove-SvtBackup
```

Deletes the backups with the specified backup name.

### EXAMPLE 2
```
Get-SvtBackup -VmName MyVm -Hour 3 | Remove-SvtBackup
```

Delete any backup that is at least 3 hours old for the specified virtual machine

### EXAMPLE 3
```
Get-SvtBackup | ? VmName -match "test" | Remove-SvtBackup
```

Delete all backups for all virtual machines that have "test" in their name

### EXAMPLE 4
```
Get-SvtBackup -CreatedBefore 01/01/2020 -Limit 3000 | Remove-SvtBackup
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
Author: Roy Atkins, HPE Services

This cmdlet uses the /api/backups/delete REST API POST call which creates a task to delete the specified
backup.
This call accepts multiple backup IDs, and efficiently removes multiple backups with a single task.
This also works for backups in remote clusters.

There is another REST API DELETE call (/api/backups/\<bkpId\>) which only works locally (i.e.
when
connected to a SimpliVity Virtual Appliance where the backup resides), but this fails when trying to delete
remote backups.

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtBackup.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtBackup.md)

