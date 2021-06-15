---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtHardware

## SYNOPSIS

Display HPE SimpliVity host hardware information

## SYNTAX

```PowerShell
Get-SvtHardware [[-HostName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Shows host hardware information for the specified host(s). Some properties are arrays, from the REST API response.Information in these properties can be enumerated as usual. See examples for details.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtHardware -HostName Host01 | Select-Object -ExpandProperty LogicalDrives
```

Enumerates all of the logical drives from the specified host

### EXAMPLE 2

```PowerShell
(Get-SvtHardware Host01).RaidCard
```

Enumerate all of the RAID cards from the specified host

### EXAMPLE 3

```PowerShell
Get-SvtHardware Host1,Host2,Host3
```

Shows hardware information for all hosts in the specified list

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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
