---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Restore-SVTvm

## SYNOPSIS
Restore one or more HPE SimpliVity virtual machines

## SYNTAX

### RestoreToOriginal (Default)
```
Restore-SVTvm [-RestoreToOriginal] [-BackupId] <String> [<CommonParameters>]
```

### NewVm
```
Restore-SVTvm [-VmName] <String> [-DataStoreName] <String> [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Restore one or more virtual machines hosted on HPE SimpliVity.
Use Get-SVTbackup output to pass in the
backup ID(s) and VmName(s) you'd like to restore.
You can either specify a destination datastore or restore
to the local datastore for each specified backup.
By default, the restore will create a new VM with the
same/specified name, but with a time stamp appended, or you can specify -RestoreToOriginal switch to 
overwrite the existing virtual machine.

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same name).
This makes using this command a little cumbersome by itself.
However, you can use Get-SVTBackup to 
identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTbackup -BackupName 2019-05-09T22:00:00+10:00 | Restore-SVTvm -RestoreToOriginal
```

Restores the virtual machine(s) in the specified backup to the original VM name(s)

### EXAMPLE 2
```
Get-SVTbackup -VmName MyVm | Select-Object -Last 1 | Restore-SVTvm
```

Restores the most recent backup of specified virtual machine, giving it the name of the original VM with a 
data stamp appended

## PARAMETERS

### -RestoreToOriginal
Specifies that the existing virtual machine is overwritten

```yaml
Type: SwitchParameter
Parameter Sets: RestoreToOriginal
Aliases:

Required: True
Position: 1
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -VmName
The virtual machine name(s)

```yaml
Type: String
Parameter Sets: NewVm
Aliases: Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DataStoreName
The destination datastore name

```yaml
Type: String
Parameter Sets: NewVm
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -BackupId
The UID of the backup(s) to restore from

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
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
