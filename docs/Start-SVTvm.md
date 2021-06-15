---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Start-SvtVm

## SYNOPSIS

Start a virtual machine hosted on HPE SimpliVity storage

## SYNTAX

```PowerShell
Start-SvtVm [-VmName] <String[]> [-VmId <String>] [<CommonParameters>]
```

## DESCRIPTION

Start a virtual machine hosted on HPE SimpliVity storage

## EXAMPLES

### EXAMPLE 1

```PowerShell
Start-SvtVm -VmName MyVm
```

Starts the specified virtual machine

### EXAMPLE 2

```PowerShell
Get-SvtVm -ClusterName DR01 | Start-SvtVm -VmName MyVm
```

Starts the virtual machines in the specified cluster

### EXAMPLE 3

```PowerShell
Start-SvtVm -VmName Server2016-01,RHEL8-01
```

Starts the specified virtual machines

## PARAMETERS

### -VmName

The virtual machine name to start

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -VmId

Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from the pipeline, using Get-SvtVm. This is more efficient (single call to the SimpliVity API).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
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

## RELATED LINKS
