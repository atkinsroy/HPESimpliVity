---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Update-SvtBackupUniqueSize

## SYNOPSIS

Calculate the unique size of HPE SimpliVity backups

## SYNTAX

```PowerShell
Update-SvtBackupUniqueSize [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION

Calculate the unique size of HPE SimpliVity backups

BackupId is the only unique identifier for backup objects (e.g. multiple backups can have the same name). This makes using this command a little cumbersome by itself. However, you can use Get-SvtBackup to identify the backups you want to target and then pass the output to this
command.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtBackup -VmName VM01 | Update-SvtBackupUniqueSize
```

Starts a task to calculate the unique size of the specified backup(s)

### EXAMPLE 2

```PowerShell
Get-SvtBackup -Date 26/04/2020 | Update-SvtBackupUniqueSize
```

Starts a task per backup object to calculate the unique size of backups with the specified creation date.

## PARAMETERS

### -BackupId

Use Get-SvtBackup to output the required VMs as input for this command

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

### HPE.SimpliVity.VirtualMachine

## OUTPUTS

### HPE.SimpliVity.Task

## NOTES

Author: Roy Atkins, HPE Pointnext Services

This command only updates the backups in the local cluster. Login to a SimpliVity Virtual Appliance in a remote
cluster to update the backups there. The UniqueSizeDate property is updated on the backup object(s) when you run this command

## RELATED LINKS
