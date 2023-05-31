---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCluster.md
schema: 2.0.0
---

# Get-SvtCluster

## SYNOPSIS
Display HPE SimpliVity cluster information

## SYNTAX

```
Get-SvtCluster [[-ClusterName] <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Shows cluster information from the SimpliVity Federation

Free Space is shown in green if at least 20% of the allocated storage is free,
yellow if free space is between 10% and 20% and red if less than 10% is free.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtCluster
```

Shows information about all clusters in the Federation

### EXAMPLE 2
```
Get-SvtCluster Prod01
PS C:\> Get-SvtCluster -Name Prod01
```

Shows information about the specified cluster

### EXAMPLE 3
```
Get-SvtCluster cluster1,cluster2
```

Shows information about the specified clusters

### EXAMPLE 4
```
Get-SvtCluster -ClusterName MyCluster -Raw
```

Display the specified cluster in raw JSON from the Simplivity API.

## PARAMETERS

### -ClusterName
Show information about the specified cluster only

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Raw
Display output as JSON, rather than a formatted PowerShell object.
This parameter might useful in troubleshooting
and maintaining the module.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
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

### HPE.SimpliVity.Cluster
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCluster.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCluster.md)

