---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Get-SVTdatastore

## SYNOPSIS
Display HPE SimpliVity datastore information

## SYNTAX

```
Get-SVTdatastore [[-DatastoreName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Shows datastore information from the SimpliVity Federation

## EXAMPLES

### EXAMPLE 1
```
Get-SVTdatastore
```

Shows all datastores in the Federation

### EXAMPLE 2
```
Get-SVTdatastore -Name DS01 | Export-CSV Datastore.csv
```

Writes the specified datastore information into a CSV file

### EXAMPLE 3
```
Get-SVTdatastore DS01,DS02,DS03 | Select-Object Name, SizeGB, Policy
```

Shows the specified properties for the HPE SimpliVity datastores

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.DataStore
## NOTES

## RELATED LINKS
