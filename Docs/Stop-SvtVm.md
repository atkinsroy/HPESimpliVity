---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Stop-SvtVm

## SYNOPSIS

Stop a virtual machine hosted on HPE SimpliVity storage

## SYNTAX

```PowerShell
Stop-SvtVm [-VmName] <String[]> [-VmId <String>] [<CommonParameters>]
```

## DESCRIPTION

Stop a virtual machine hosted on HPE SimpliVity storage

Stopping VMs with this command is not recommended. The VM will be in a "crash consistent" state. This action may lead to some data loss.

A better option is to use the VMware PowerCLI Stop-VMGuest cmdlet. This shuts down the Guest OS gracefully.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Stop-SvtVm -VmName MyVm
```

Stops the specified virtual machine

### EXAMPLE 2

```PowerShell
Get-SvtVm -Datastore DS01 | Stop-SvtVm
```

Stops all the VMs on the specified datastore

### EXAMPLE 3

```PowerShell
Stop-SvtVm -VmName Server2016-01,Server2016-02,Server2016-03
```

Stops the specified virtual machines

## PARAMETERS

### -VmName

The virtual machine name to stop

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
