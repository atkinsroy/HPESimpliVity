---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtThroughput

## SYNOPSIS

Display information about HPE SimpliVity cluster throughput

## SYNTAX

```PowerShell
Get-SvtThroughput [[-ClusterName] <String>] [[-Hour] <Int32>] [[-OffsetHour] <Int32>] [<CommonParameters>]
```

## DESCRIPTION

Calculates the throughput between each pair of omnistack_clusters in the federation

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtThroughput
```

Displays the throughput information for the first cluster in the Federation, (alphabetically,
by name)

### EXAMPLE 2

```PowerShell
Get-SvtThroughput -Cluster Prod01
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Management.Automation.PSCustomObject

## NOTES

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
