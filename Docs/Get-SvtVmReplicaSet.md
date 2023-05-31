---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtVmReplicaSet.md
schema: 2.0.0
---

# Get-SvtVmReplicaSet

## SYNOPSIS
Display the primary and secondary replica locations for HPE SimpliVity virtual machines

## SYNTAX

### ByVm (Default)
```
Get-SvtVmReplicaSet [[-VmName] <String[]>] [<CommonParameters>]
```

### ByDatastore
```
Get-SvtVmReplicaSet -DatastoreName <String[]> [<CommonParameters>]
```

### ByCluster
```
Get-SvtVmReplicaSet -ClusterName <String[]> [<CommonParameters>]
```

### ByHost
```
Get-SvtVmReplicaSet -HostName <String> [<CommonParameters>]
```

## DESCRIPTION
Display the primary and secondary replica locations for HPE SimpliVity virtual machines

## EXAMPLES

### EXAMPLE 1
```
Get-SvtVmReplicaSet
```

Displays the primary and secondary locations for all virtual machine replica sets.

## PARAMETERS

### -VmName
Display information for the specified virtual machine

```yaml
Type: String[]
Parameter Sets: ByVm
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DatastoreName
Display information for virtual machines on the specified datastore

```yaml
Type: String[]
Parameter Sets: ByDatastore
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterName
Display information for virtual machines on the specified cluster

```yaml
Type: String[]
Parameter Sets: ByCluster
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HostName
Display information for virtual machines on the specified host

```yaml
Type: String
Parameter Sets: ByHost
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtVmReplicaSet.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtVmReplicaSet.md)

