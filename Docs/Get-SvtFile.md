---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtFile.md
schema: 2.0.0
---

# Get-SvtFile

## SYNOPSIS
Display the virtual disk, partition and file information from a SimpliVity backup

## SYNTAX

```
Get-SvtFile -BackupId <String> [[-VirtualDisk] <String>] [[-PartitionNumber] <String>] [[-FilePath] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Displays the backed up files inside a SimpliVity backup.
Different output is produced, depending on the
parameters provided.
BackupId is a mandatory parameter and can be passed in from Get-SvtBackup.

If no optional parameters are provided, or if VirtualDisk is not specified, the virtual disks contained
in the backup are shown.
If a virtual disk name is provided, the partitions within the specified virtual
disk are shown.
If the virtual disk and partition are provided, the files in the root path for the partition
are shown.
If all three optional parameters are provided, the specified backed up files are shown.

Notes:
1.
This command only works with backups from Microsoft Windows VMs.
with Linux VMs, only backed up 
   virtual disks and partitions can be displayed (files cannot be displayed).
2.
This command only works with native SimpliVity backups.
(Backups on StoreOnce appliances do not work)
3.
Virtual disk names and folder paths are case sensitive

## EXAMPLES

### EXAMPLE 1
```
$Backup = Get-SvtBackup -VmName Win2019-01 -Limit 1
PS C:\> $Backup | Get-SvtFile
```

The first command identifies the most recent backup of the specified VM.
The second command displays the virtual disks contained within the backup

### EXAMPLE 2
```
$Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
PS C:\> $Backup | Get-SvtFile -VirtualDisk Win2019-01.vmdk
```

The first command identifies the most recent backup of the specified VM taken on a specific date.
The second command displays the partitions within the specified virtual disk.
Virtual disk names are
case sensitive

### EXAMPLE 3
```
Get-SvtFile -BackupId 5f5f7f06...0b509609c8fb -VirtualDisk Win2019-01.vmdk -PartitionNumber 4
```

Shows the contents of the root folder on the specified partition inside the specified backup

### EXAMPLE 4
```
$Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
PS C:\> $Backup | Get-SvtFile Win2019-01.vmdk 4
```

Shows the backed up files at the root of the specified partition, using positional parameters

### EXAMPLE 5
```
$Backup = Get-SvtBackup -VmName Win2019-02 -Date 26/04/2020 -Limit 1
PS C:\> $Backup | Get-SvtFile Win2019-01.vmdk 4 /Users/Administrator/Documents
```

Shows the specified backed up files within the specified partition, using positional parameters.
File
names are case sensitive.

### EXAMPLE 6
```
$Backup = '5f5f7f06-a485-42eb-b4c0-0b509609c8fb' # This is a valid Backup ID
PS C:\> $Backup | Get-SvtFile -VirtualDisk Win2019-01_1.vmdk -PartitionNumber 2 -FilePath '/Log Files'
```

The first command identifies the desired backup.
The second command displays the specified backed up
files using named parameters.
Quotes are used because the file path contains a space.
File names are
case sensitive.

## PARAMETERS

### -BackupId
The Backup Id for the desired backup.
Use Get-SvtBackup to output the required backup as input for
this command

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -VirtualDisk
The virtual disk name contained within the backup, including file suffix (".vmdk")

```yaml
Type: String
Parameter Sets: (All)
Aliases: Disk

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PartitionNumber
The partition number within the specified virtual disk

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
The folder path for the backed up files

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Backup
## OUTPUTS

### HPE.SimpliVity.VirtualDisk
### HPE.SimpliVity.Partition
### HPE.SimpliVity.File
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtFile.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtFile.md)

