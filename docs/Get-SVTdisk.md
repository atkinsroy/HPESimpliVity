---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTdisk

## SYNOPSIS
Display HPE SimpliVity physical disk information

## SYNTAX

```
Get-SVTdisk [[-HostName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Shows physical disk information for the specified host(s).
This includes the
installed storage kit, which is not provided by the API, but it derived from
the host model, the number of disks and the disk capacities.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTdisk
```

Shows physical disk information for all SimpliVity hosts in the federation.

### EXAMPLE 2
```
Get-SVTdisk -HostName Host01
```

Shows physical disk information for the specified SimpliVity host.

### EXAMPLE 3
```
Get-SVTdisk -HostName Host01 | Select-Object -First 1 | Format-List
```

Show all of the available information about the first disk on the specified host.

### EXAMPLE 4
```
Get-SVThost -Cluster PROD | Get-SVTdisk
```

Shows physical disk information for all hosts in the specified cluster.

### EXAMPLE 5
```
Get-SVThost Host1,Host2,Host3
```

Shows physical disk information for all hosts in the specified list

## PARAMETERS

### -HostName
Show information for the specified host only

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Host
## OUTPUTS

### HPE.SimpliVity.Hardware
## NOTES

## RELATED LINKS
