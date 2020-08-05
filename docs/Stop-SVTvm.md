---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Stop-SVTvm

## SYNOPSIS
Stop a virtual machine hosted on HPE SimpliVity storage

## SYNTAX

```
Stop-SVTvm [-VmName] <String[]> [-VmId <String>] [<CommonParameters>]
```

## DESCRIPTION
Stop a virtual machine hosted on HPE SimpliVity storage

Stopping VMs with this command is not recommended.
The VM will be in a "crash consistent" state.
This action may lead to some data loss.

A better option is to use the VMware PowerCLI Stop-VMGuest cmdlet.
This shuts down the Guest OS gracefully.

## EXAMPLES

### EXAMPLE 1
```
Stop-SVTvm -VmName MyVm
```

Stops the specified virtual machine

### EXAMPLE 2
```
Get-SVTvm -Datastore DS01 | Stop-SVTvm
```

Stops all the VMs on the specified datastore

### EXAMPLE 3
```
Stop-SVTvm -VmName Server2016-01,Server2016-02,Server2016-03
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
Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from 
the pipeline, using Get-SVTvm.
This is more efficient (single call to the SimpliVity API).

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

## RELATED LINKS
