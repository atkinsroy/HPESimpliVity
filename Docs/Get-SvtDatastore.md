---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtDatastore.md
schema: 2.0.0
---

# Get-SvtDatastore

## SYNOPSIS
Display HPE SimpliVity datastore information

## SYNTAX

```
Get-SvtDatastore [[-DatastoreName] <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Shows datastore information from the SimpliVity Federation

## EXAMPLES

### EXAMPLE 1
```
Get-SvtDatastore
```

Shows all datastores in the Federation

### EXAMPLE 2
```
Get-SvtDatastore -Name DS01 | Export-CSV Datastore.csv
```

Writes the specified datastore information into a CSV file

### EXAMPLE 3
```
Get-SvtDatastore DS01,DS02,DS03 | Select-Object Name, SizeGB, Policy
```

Shows the specified properties for the HPE SimpliVity datastores

### EXAMPLE 4
```
Get-SvtDatastore -Name DS02 -Raw
```

Display the specified datastore in raw JSON from the Simplivity API.

## PARAMETERS

### -DatastoreName
Show information for the specified datastore only

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

### HPE.SimpliVity.Datastore
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtDatastore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtDatastore.md)

