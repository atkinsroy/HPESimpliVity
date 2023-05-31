---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Restore-SvtFile.md
schema: 2.0.0
---

# Restore-SvtFile

## SYNOPSIS
Restore files from a SimpliVity backup to a specified virtual machine.

## SYNTAX

```
Restore-SvtFile [-VmName] <String> -RestorePath <Object> [<CommonParameters>]
```

## DESCRIPTION
This command will restore files from a backup into an ISO file that is then connected to the specified
virtual machine.

Notes:
1.
This command only works on backups taken from guests running Microsoft Windows.
2.
The target virtual machine must be running Microsoft Windows.
3.
The DVD drive on the target virtual machine must be disconnected, otherwise the restore will fail
4.
This command relies on the input from Get-SvtFile to pass in a valid backup file list to restore
5.
Whilst it is possible to use Get-SvtFile to list files in multiple backups, this command will only
   restore files from the first backup passed in.
Files in subsequent backups are ignored, because only one
   DVD drive can be mounted on the target virtual machine.
6.
Folder size matters.
The restore will fail if file sizes exceed a DVD capacity.
When restoring a large
   amount of data, it might be faster to restore the entire virtual machine and recover the required files
   from the restored virtual disk.
7.
File level restores are restricted to nine virtual disks per virtual controller.
When viewing the virtual
   disks with Get-SvtFile, you will only see the first nine disks if they are all attached to the same
   virtual controller.
In this case, you must restore the entire VM and restore the required files from the
   restored virtual disk (VMDK) files.

## EXAMPLES

### EXAMPLE 1
```
$Backup = Get-SvtBackup -VmName Win2019-01 -Name 2020-04-26T18:00:00+10:10
PS C:\> $File = $Backup | Get-SvtFile Win2019-01.vmdk 4 '/Log Files'
PS C:\> $File | Restore-SvtFile -VmName Win2019-02
```

The first command identifies the desired backup.
The second command enumerates the files from the specified virtual disk, partition and file path in the backup
The third command restores those files to an ISO and then connects this to the specified virtual machine.

## PARAMETERS

### -VmName
The target virtual machine.
Ensure the DVD drive is disconnected

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RestorePath
An array containing the backup ID and the full path of the folder to restore.
This consists of the virtual
disk name, partition and folder name.
The Get-SvtFile provides this parameter in the expected format,
e.g.
"/Win2019-01.vmdk/4/Users/Administrator/Documents".

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
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

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Restore-SvtFile.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Restore-SvtFile.md)

