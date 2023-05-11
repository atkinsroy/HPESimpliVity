---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Stop-SvtBackup

## SYNOPSIS

Stops (cancels) a currently executing HPE SimpliVity backup

## SYNTAX

```PowerShell
Stop-SvtBackup [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION

Stops (cancels) a currently executing HPE SimpliVity backup

BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtBackup -BackupName '2019-05-12T01:00:00-04:00' | Stop-SvtBackup
```

Cancels the backup or backups with the specified backup name.

## PARAMETERS

### -BackupId

Specify the Backup ID(s) for the backup(s) to cancel

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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
