---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtThroughput.md
schema: 2.0.0
---

# Get-SvtThroughput

## SYNOPSIS
Display information about HPE SimpliVity cluster throughput

## SYNTAX

```
Get-SvtThroughput [[-ClusterName] <String>] [[-Hour] <Int32>] [[-OffsetHour] <Int32>] [-Raw]
 [<CommonParameters>]
```

## DESCRIPTION
Calculates the throughput between a source cluster and the other omnistack_clusters in the federation

## EXAMPLES

### EXAMPLE 1
```
Get-SvtThroughput
```

Displays the throughput information for the first cluster in the Federation, (alphabetically,
by name)

### EXAMPLE 2
```
Get-SvtThroughput -Cluster Prod01
```

Displays the throughput information for the specified cluster

### EXAMPLE 3
```
Get-SvtThroughput -Cluster Prod01 -Raw
```

Display throughput information from the specified cluster in raw JSON from the Simplivity API.

## PARAMETERS

### -ClusterName
Specify a cluster name

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-SvtCluster |
                Sort-Object ClusterName | Select-Object -ExpandProperty ClusterName -First 1)
Accept pipeline input: False
Accept wildcard characters: False
```

### -Hour
Show throughput for the specified number of hours (starting from OffsetHour)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 12
Accept pipeline input: False
Accept wildcard characters: False
```

### -OffsetHour
Show throughput starting from the specified offset (hours from now, default is now)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0
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

### None
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtThroughput.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtThroughput.md)

