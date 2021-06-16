---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtHost

## SYNOPSIS

Display HPE SimpliVity host information

## SYNTAX

### ByHostName (Default)

```PowerShell
Get-SvtHost [[-HostName] <String[]>] [<CommonParameters>]
```

### ByClusterName

```PowerShell
Get-SvtHost [-ClusterName <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Shows host information from the SimpliVity Federation.

Free Space is shown in green if at least 20% of the allocated storage is free, yellow if free space is between 10% and 20% and red if less than 10% is free.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtHost
```

Shows all hosts in the Federation

### EXAMPLE 2

```PowerShell
Get-SvtHost -Name Host01
PS C:\> Get-SvtHost Host01,Host02
```

Shows the specified host(s)

### EXAMPLE 3

```PowerShell
Get-SvtHost -ClusterName MyCluster
```

Shows hosts in specified HPE SimpliVity cluster(s)

### EXAMPLE 4

```PowerShell
Get-SvtHost | Where-Object DataCenter -eq MyDC | Format-List *
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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
