---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtClone.md
schema: 2.0.0
---

# New-SvtClone

## SYNOPSIS
Clone a Virtual Machine hosted on SimpliVity storage

## SYNTAX

```
New-SvtClone [-VmName] <String> [[-CloneName] <String>] [[-ConsistencyType] <String>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet will clone the specified virtual machine, using the new name provided.

## EXAMPLES

### EXAMPLE 1
```
New-SvtClone -VmName MyVm1
```

Create a clone with the default name 'MyVm1-clone-200212102304', where the suffix is a date stamp in
the form 'yyMMddhhmmss'

### EXAMPLE 2
```
New-SvtClone -VmName Win2019-01 -CloneName Win2019-Clone
PS C:\> New-SvtClone -VmName Win2019-01 -CloneName Win2019-Clone -ConsistencyType NONE
```

Both commands do the same thing, they create an application consistent clone of the specified
virtual machine, using a snapshot

### EXAMPLE 3
```
New-SvtClone -VmName Linux-01 -CloneName Linux-01-New -ConsistencyType DEFAULT
```

Create a crash-consistent clone of the specified virtual machine

### EXAMPLE 4
```
New-SvtClone -VmName Win2019-06 -CloneName Win2019-Clone -ConsistencyType VSS
```

Creates an application consistent clone of the specified Windows VM, using a VSS snapshot.
The clone
will fail for None-Windows virtual machines.

## PARAMETERS

### -VmName
Specify the VM to clone

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

### -CloneName
Specify the name of the new clone

```yaml
Type: String
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 2
Default value: "$VmName-clone-$(Get-Date -Format 'yyMMddhhmmss')"
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConsistencyType
Available options are:
1.
NONE - This is the default and creates a crash consistent backup
2.
DEFAULT - Create application consistent backups using VMware Snapshot
3.
VSS - Create application consistent backups using Microsoft VSS in the guest operating system.
Refer
   to the admin guide for requirements and supported applications

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: NONE
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.VirtualMachine
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtClone.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtClone.md)

