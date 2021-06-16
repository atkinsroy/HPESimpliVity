---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtDisk

## SYNOPSIS

Display HPE SimpliVity physical disk information

## SYNTAX

```PowerShell
Get-SvtDisk [[-HostName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Shows physical disk information for the specified host(s).
This includes the
installed storage kit, which is not provided by the API, but it derived from
the host model, the number of disks and the disk capacities.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtDisk
```

Shows physical disk information for all SimpliVity hosts in the federation.

### EXAMPLE 2

```PowerShell
Get-SvtDisk -HostName Host01
```

Shows physical disk information for the specified SimpliVity host.

### EXAMPLE 3

```PowerShell
Get-SvtDisk -HostName Host01 | Select-Object -First 1 | Format-List
```

Show all of the available information about the first disk on the specified host.

### EXAMPLE 4

```PowerShell
Get-SvtHost -Cluster PROD | Get-SvtDisk
```

Shows physical disk information for all hosts in the specified cluster.

### EXAMPLE 5

```PowerShell
Get-SvtHost Host1,Host2,Host3 | Get-SvtDisk
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

### HPE.SimpliVity.Disk

## NOTES

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
