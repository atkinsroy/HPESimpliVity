---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTcluster.md
schema: 2.0.0
---

# Get-SVTcluster

## SYNOPSIS
Display HPE SimpliVity cluster information

## SYNTAX

```
Get-SVTcluster [[-ClusterName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Shows cluster information from the SimpliVity Federation

## EXAMPLES

### EXAMPLE 1
```
Get-SVTcluster
```

Shows information about all clusters in the Federation

### EXAMPLE 2
```
Get-SVTcluster Prod01
PS C:\> Get-SVTcluster -Name Prod01
```

Shows information about the specified cluster

### EXAMPLE 3
```
Get-SVTcluster cluster1,cluster2
```

Shows information about the specified clusters

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Cluster
## NOTES

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTcluster.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTcluster.md)

