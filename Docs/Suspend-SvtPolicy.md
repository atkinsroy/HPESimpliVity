---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Suspend-SvtPolicy.md
schema: 2.0.0
---

# Suspend-SvtPolicy

## SYNOPSIS
Suspends the HPE SimpliVity backup policy for a host, a cluster or the federation

## SYNTAX

### ByHost (Default)
```
Suspend-SvtPolicy [-HostName] <String> [<CommonParameters>]
```

### ByCluster
```
Suspend-SvtPolicy -ClusterName <String> [<CommonParameters>]
```

### ByFederation
```
Suspend-SvtPolicy [-Federation] [<CommonParameters>]
```

## DESCRIPTION
Suspend the HPE SimpliVity backup policy for a host, a cluster or the federation

## EXAMPLES

### EXAMPLE 1
```
Suspend-SvtPolicy -Federation
```

Suspends backup policies for the entire federation

NOTE: This command will only work when connected to a SimpliVity Virtual Appliance, (not when connected
to a Managed Virtual Appliance)

### EXAMPLE 2
```
Suspend-SvtPolicy -ClusterName Prod
```

Suspend backup policies for the specified cluster

### EXAMPLE 3
```
Suspend-SvtPolicy -HostName host01
```

Suspend backup policies for the specified host

## PARAMETERS

### -HostName
Apply to specified host name

```yaml
Type: String
Parameter Sets: ByHost
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterName
Apply to specified Cluster name

```yaml
Type: String
Parameter Sets: ByCluster
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Federation
Apply to federation

```yaml
Type: SwitchParameter
Parameter Sets: ByFederation
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Suspend-SvtPolicy.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Suspend-SvtPolicy.md)

