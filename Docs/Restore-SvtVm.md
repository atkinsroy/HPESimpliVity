---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Restore-SvtVm.md
schema: 2.0.0
---

# Restore-SvtVm

## SYNOPSIS
Restore one or more HPE SimpliVity virtual machines

## SYNTAX

### RestoreToOriginal (Default)
```
Restore-SvtVm [-RestoreToOriginal] [-BackupId] <String> [<CommonParameters>]
```

### NewVm
```
Restore-SvtVm [[-NewVmName] <String>] [-DatastoreName] <String> [-BackupId] <String> [<CommonParameters>]
```

## DESCRIPTION
Restore one or more virtual machines from backups hosted on HPE SimpliVity storage.
Use output from the
Get-SvtBackup command to pass in the backup(s) you want to restore.
By default, a new VM is created for each
backup passed in.
The new virtual machines are named after the original VM name with a timestamp suffix to make
them unique.
Alternatively, you can specify the -RestoreToOriginal switch to restore to the original virtual
machines.
This action will overwrite the existing virtual machines, recovering to the state of the backup used.

However, if -NewVmName is specified, you can only pass in one backup object.
The first backup passed in will
be restored with the specified VmName, but subsequent restores will not be attempted and an error will be
displayed.
In addition, if you specify a new VM name that this is already in use by an existing VM, then the
restore task will fail with a duplicate name error.

By default the datastore used by the original VMs are used for each restore.
If -DatastoreName is specified,
the restored VMs will be located on the specified datastore.

BackupId is the only unique identifier for backup objects (e.g.
multiple backups can have the same name).
This makes using this command a little cumbersome by itself.
However, you can use Get-SvtBackup to
identify the backups you want to target and then pass the output to this command.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtBackup -BackupName 2019-05-09T22:00:00+10:00 | Restore-SvtVm -RestoreToOriginal
```

Restores the virtual machine(s) in the specified backup to the original virtual machine(s)

### EXAMPLE 2
```
Get-SvtBackup -VmName MyVm -Limit 1 | Restore-SvtVm
```

Restores the most recent backup of specified virtual machine, giving it a new name comprising of the name of
the original VM with a date stamp appended to ensure uniqueness

### EXAMPLE 3
```
Get-SvtBackup -VmName MyVm -Limit 1 | Restore-SvtVm -NewVmName MyOtherVM
```

Restores the most recent backup of specified virtual machine, giving it the specified name.
NOTE: this command
will only work for the first backup passed in.
Subsequent restores are not attempted and an error is displayed.

### EXAMPLE 4
```
$LatestBackup = Get-SvtVm -VmName VM1,VM2,VM3 | Foreach-Object { Get-SvtBackup -VmName $_.VmName -Limit 1 }
PS> $LatestBackup | Restore-SvtVm -DatastoreName DS2
```

Restores the most recent backup of each specified virtual machine, creating a new copy of each on the specified
datastore.
The virtual machines will have new names comprising of the name of the original VM with a date
stamp appended to ensure uniqueness

## PARAMETERS

### -RestoreToOriginal
Specifies that the VM is restored to original location, overwriting the existing virtual machine, if it exists

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

### -NewVmName
Specify a new name for the virtual machine when restoring one VM only

```yaml
Type: String
Parameter Sets: NewVm
Aliases: VmName

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DatastoreName
The destination datastore name.
If not specified, the original datastore location from each backup is used

```yaml
Type: String
Parameter Sets: NewVm
Aliases:

Required: True
Position: 3
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
Position: 5
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

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Restore-SvtVm.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Restore-SvtVm.md)

