---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Rename-SVTbackup

## SYNOPSIS
Rename existing HPE SimpliVity backup(s)

## SYNTAX

```
Rename-SVTbackup [-BackupName] <String> [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Rename existing HPE SimpliVity backup(s).

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same name). 
This makes using this command a little cumbersome by itself.
However, you can use Get-SVTBackup to identify 
the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTbackup -BackupName "Pre-SQL update"
PS C:\> Get-SVTbackup -BackupName 2019-05-11T09:30:00-04:00 | Rename-SVTBackup "Pre-SQL update"
```

The first command confirms the backup name is not in use.
The second command renames the specified backup(s).

## PARAMETERS

### -BackupName
The new backup name.
Must be a new unique name.
The command fails if there are existing backups with 
this name.

```yaml
Type: String
Parameter Sets: (All)
Aliases: NewName, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupId
The backup Ids of the backups to be renamed

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
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
