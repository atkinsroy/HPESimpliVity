---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVThost

## SYNOPSIS
Display HPE SimpliVity host information

## SYNTAX

### ByHostName (Default)
```
Get-SVThost [[-HostName] <String[]>] [<CommonParameters>]
```

### ByClusterName
```
Get-SVThost [-ClusterName <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Shows host information from the SimpliVity Federation.

## EXAMPLES

### EXAMPLE 1
```
Get-SVThost
```

Shows all hosts in the Federation

### EXAMPLE 2
```
Get-SVThost -Name Host01
PS C:\> Get-SVThost Host01,Host02
```

Shows the specified host(s)

### EXAMPLE 3
```
Get-SVThost -ClusterName MyCluster
```

Shows hosts in specified HPE SimpliVity cluster(s)

### EXAMPLE 4
```
Get-SVTHost | Where-Object DataCenter -eq MyDC | Format-List *
```

Shows all properties for all hosts in the specified Datacenter

## PARAMETERS

### -HostName
Show the specified host only

```yaml
Type: String[]
Parameter Sets: ByHostName
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterName
Show hosts from the specified SimpliVity cluster only

```yaml
Type: String[]
Parameter Sets: ByClusterName
Aliases:

Required: False
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

### HPE.SimpliVity.Host
## NOTES

## RELATED LINKS
