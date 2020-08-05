---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Get-SVTclusterConnected

## SYNOPSIS
Displays information about other HPE SimpliVity clusters

## SYNTAX

```
Get-SVTclusterConnected [[-ClusterName] <String>] [<CommonParameters>]
```

## DESCRIPTION
Displays information about other HPE SimpliVity clusters directly connected to the specified cluster

## EXAMPLES

### EXAMPLE 1
```
Get-SVTclusterConnected -ClusterName Production
```

Displays information about the clusters directly connected to the specified cluster

### EXAMPLE 2
```
Get-SVTclusterConnected
```

Displays information about the first cluster in the federation (by cluster name, alphabetically)

## PARAMETERS

### -ClusterName
Specify a 'source' cluster name to display other clusters directly connected to it

If no cluster is specified, the first cluster in the Federation is used (alphabetically)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### PSCustomObject
## NOTES

## RELATED LINKS
