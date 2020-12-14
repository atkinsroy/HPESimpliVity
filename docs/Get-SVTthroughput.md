---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTthroughput

## SYNOPSIS
Display information about HPE SimpliVity cluster throughput

## SYNTAX

```
Get-SVTthroughput [[-ClusterName] <String>] [[-Hour] <Int32>] [[-OffsetHour] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Calculates the throughput between each pair of omnistack_clusters in the federation

## EXAMPLES

### EXAMPLE 1
```
Get-SVTthroughput
```

Displays the throughput information for the first cluster in the Federation, (alphabetically,
by name)

### EXAMPLE 2
```
Get-SVTthroughput -Cluster Prod01
```

Displays the throughput information for the specified cluster

## PARAMETERS

### -ClusterName
Specify a cluster name

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-SVTcluster | 
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### PSCustomObject
## NOTES

## RELATED LINKS
