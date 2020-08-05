---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Start-SVTvm

## SYNOPSIS
Start a virtual machine hosted on HPE SimpliVity storage

## SYNTAX

```
Start-SVTvm [-VmName] <String[]> [-VmId <String>] [<CommonParameters>]
```

## DESCRIPTION
Start a virtual machine hosted on HPE SimpliVity storage

## EXAMPLES

### EXAMPLE 1
```
Start-SVTvm -VmName MyVm
```

Starts the specified virtual machine

### EXAMPLE 2
```
Get-SVTvm -ClusterName DR01 | Start-SVTvm -VmName MyVm
```

Starts the virtual machines in the specified cluster

### EXAMPLE 3
```
Start-SVTvm -VmName Server2016-01,RHEL8-01
```

Starts the specfied virtual machines

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
