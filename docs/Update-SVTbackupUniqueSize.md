---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Update-SVTbackupUniqueSize

## SYNOPSIS
Calculate the unique size of HPE SimpliVity backups

## SYNTAX

```
Update-SVTbackupUniqueSize [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Calculate the unique size of HPE SimpliVity backups

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same 
name).
This makes using this command a little cumbersome by itself.
However, you can use Get-SVTBackup 
to identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTbackup -VmName VM01 | Update-SVTbackupUniqueSize
```

Starts a task to calculate the unique size of the specified backup(s)

### EXAMPLE 2
```
Get-SVTbackup -Date 26/04/2020 | Update-SVTbackupUniqueSize
```

Starts a task per backup object to calculate the unique size of backups with the specified creation date.

## PARAMETERS

### -BackupId
Use Get-SVTbackup to output the required VMs as input for this command

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
This command only updates the backups in the local cluster.
Login to an OVC in a remote cluster to 
update the backups there.
The UniqueSizeDate property is updated on the backup object(s) when you run 
this command

## RELATED LINKS
