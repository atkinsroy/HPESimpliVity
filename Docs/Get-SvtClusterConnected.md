---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtClusterConnected.md
schema: 2.0.0
---

# Get-SvtClusterConnected

## SYNOPSIS
Displays information about the connected HPE SimpliVity clusters in a Federation

## SYNTAX

```
Get-SvtClusterConnected [[-ClusterName] <String>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Displays information about other HPE SimpliVity clusters directly connected to the specified cluster

## EXAMPLES

### EXAMPLE 1
```
Get-SvtClusterConnected -ClusterName Production
```

Displays information about the clusters directly connected to the specified cluster

### EXAMPLE 2
```
Get-SvtClusterConnected
```

Displays information about the first cluster in the federation (by cluster name, alphabetically)

### EXAMPLE 3
```
Get-SvtClusterConnected -ClusterName Prod01 -Raw
```

Display the connected cluster for the specified cluster in raw JSON from the Simplivity API.

## PARAMETERS

### -ClusterName
Specify a 'source' cluster name to display information about the SimpliVity clusters directly connected to it

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

### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtClusterConnected.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtClusterConnected.md)

