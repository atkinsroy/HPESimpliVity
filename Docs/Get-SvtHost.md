---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHost.md
schema: 2.0.0
---

# Get-SvtHost

## SYNOPSIS
Display HPE SimpliVity host information

## SYNTAX

### ByHostName (Default)
```
Get-SvtHost [[-HostName] <String[]>] [-Raw] [<CommonParameters>]
```

### ByClusterName
```
Get-SvtHost [-ClusterName <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Shows host information from the SimpliVity Federation.

Free Space is shown in green if at least 20% of the allocated storage is free,
yellow if free space is between 10% and 20% and red if less than 10% is free.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtHost
```

Shows all hosts in the Federation

### EXAMPLE 2
```
Get-SvtHost -Name Host01
PS C:\> Get-SvtHost Host01,Host02
```

Shows the specified host(s)

### EXAMPLE 3
```
Get-SvtHost -ClusterName MyCluster
```

Shows hosts in specified HPE SimpliVity cluster(s)

### EXAMPLE 4
```
Get-SvtHost | Where-Object DataCenter -eq MyDC | Format-List *
```

Shows all properties for all hosts in the specified Datacenter

### EXAMPLE 5
```
Get-SvtHost -ClusterName MyCluster -Raw
```

Display the specified hosts in raw JSON from the Simplivity API.

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

### HPE.SimpliVity.Host
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHost.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHost.md)

