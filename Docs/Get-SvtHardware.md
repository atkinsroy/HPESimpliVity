---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHardware.md
schema: 2.0.0
---

# Get-SvtHardware

## SYNOPSIS
Display HPE SimpliVity host hardware information

## SYNTAX

```
Get-SvtHardware [[-HostName] <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Shows host hardware information for the specified host(s).
Some properties are
arrays, from the REST API response.
Information in these properties can be enumerated as
usual.
See examples for details.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtHardware -HostName Host01 | Select-Object -ExpandProperty LogicalDrives
```

Enumerates all of the logical drives from the specified host

### EXAMPLE 2
```
(Get-SvtHardware Host01).RaidCard
```

Enumerate all of the RAID cards from the specified host

### EXAMPLE 3
```
Get-SvtHardware Host1,Host2,Host3
```

Shows hardware information for all hosts in the specified list

### EXAMPLE 4
```
Get-SvtHardware -HostName Host01 -Raw
```

Display the specified hardware in raw JSON from the Simplivity API.

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
### HPE.SimpliVity.Host
## OUTPUTS

### HPE.SimpliVity.Hardware
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHardware.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtHardware.md)

