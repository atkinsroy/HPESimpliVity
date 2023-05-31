---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Move-SvtVm.md
schema: 2.0.0
---

# Move-SvtVm

## SYNOPSIS
Move one or more existing virtual machines from one HPE SimpliVity datastore to another

## SYNTAX

```
Move-SvtVm [-VmName] <String> [-DatastoreName] <String> [<CommonParameters>]
```

## DESCRIPTION
Relocates the specified virtual machines to a different datastore in the federation.
The datastore can be
in the same or a different datacenter.
Consider the following when moving a virtual machine:
1.
You must power off the OS guest before moving, otherwise the operation fails
2.
In its new location, make sure the moved VM boots up after the local SVA and shuts down before it
3.
Any pre-move backups (local or remote) stay associated with a VM after it moves.
You can use these backups
to restore the moved VM(s)
4.
HPE OmniStack only supports one move operation per VM at a time.
You must wait for the task to complete before
attempting to move the same VM again
5.
If moving VM(s) out of the current cluster, DRS rules (created by the Intelligent Workload Optimizer) will
vMotion the moved VM(s) to the destination

## EXAMPLES

### EXAMPLE 1
```
Move-SvtVm -VmName MyVm -Datastore DR-DS01
```

Moves the specified VM to the specified datastore

### EXAMPLE 2
```
"VM1", "VM2" | Move-SvtVm -Datastore DS03
```

Moves the two VMs to the specified datastore

### EXAMPLE 3
```
Get-VM | Where-Object VmName -match "WEB" | Move-SvtVm -Datastore DS03
PS C:\> Get-SvtTask
```

Move VM(s) with "Web" in their name to the specified datastore.
Use Get-SvtTask to monitor the progress
of the move task(s)

## PARAMETERS

### -VmName
The name(s) of the virtual machines you'd like to move

```yaml
Type: String
Parameter Sets: (All)
Aliases: Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -DatastoreName
The destination datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
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
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Move-SvtVm.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Move-SvtVm.md)

