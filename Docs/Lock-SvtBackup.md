---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Lock-SvtBackup

## SYNOPSIS

Locks HPE SimpliVity backups to prevent them from expiring

## SYNTAX

```PowerShell
Lock-SvtBackup [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION

Locks HPE SimpliVity backups to prevent them from expiring

BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtBackup -BackupName 2019-05-09T22:00:01-04:00 | Lock-SvtBackup
PS C:\> Get-SvtTask
```

Locks the backup(s) with the specified name. Use Get-SvtTask to track the progress of the task(s).

## PARAMETERS

### -BackupId

Lock the backup(s) with the specified backup ID(s)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
