---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtBackupRetention.md
schema: 2.0.0
---

# Set-SvtBackupRetention

## SYNOPSIS
Set the retention of existing HPE SimpliVity backups

## SYNTAX

### ByDay (Default)
```
Set-SvtBackupRetention [-RetentionDay] <Int32> [-BackupId] <String> [<CommonParameters>]
```

### ByHour
```
Set-SvtBackupRetention [-RetentionHour] <Int32> [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Change the retention on existing SimpliVity backup.

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same
name).
This makes using this command a little cumbersome by itself.
However, you can use Get-SvtBackup
to identify the backups you want to target and then pass the output to this command.

Note: There is currently a known issue with the REST API that prevents you from setting retention times
that will cause backups to immediately expire.
if you try to decrease the retention for a backup policy
where backups will be immediately expired, you'll receive an error in the task.

## EXAMPLES

### EXAMPLE 1
```
Get-Backup -BackupName 2019-05-09T22:00:01-04:00 | Set-SvtBackupRetention -RetentionDay 21
```

Gets the backups with the specified name and then sets the retention to 21 days.

### EXAMPLE 2
```
Get-Backup -VmName Win2019-04 -Limit 1 | Set-SvtBackupRetention -RetentionHour 12
```

Get the latest backup of the specified virtual machine and then sets the retention to 12 hours.

## PARAMETERS

### -RetentionDay
The new retention you would like to set, in days.

```yaml
Type: Int32
Parameter Sets: ByDay
Aliases:

Required: True
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionHour
The new retention you would like to set, in hours.

```yaml
Type: Int32
Parameter Sets: ByHour
Aliases:

Required: True
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupId
The UID of the backup you'd like to set the retention for

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
Author: Roy Atkins, HPE Services

OMNI-53536: Setting the retention time to a time that causes backups to be deleted fails

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtBackupRetention.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtBackupRetention.md)

