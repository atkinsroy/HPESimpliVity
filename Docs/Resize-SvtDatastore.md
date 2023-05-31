---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Resize-SvtDatastore.md
schema: 2.0.0
---

# Resize-SvtDatastore

## SYNOPSIS
Resize a HPE SimpliVity Datastore

## SYNTAX

```
Resize-SvtDatastore [-DatastoreName] <String> [-SizeGB] <Int32> [<CommonParameters>]
```

## DESCRIPTION
Resizes a specified datastore to the specified size in GB.
The datastore size can be
between 1GB and 1,048,576 GB (1,024TB).

## EXAMPLES

### EXAMPLE 1
```
Resize-SvtDatastore -DatastoreName ds01 -SizeGB 1024
```

Resizes the specified datastore to 1TB

## PARAMETERS

### -DatastoreName
Apply to specified datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases: Name

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SizeGB
The new total size of the datastore in GB

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Resize-SvtDatastore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Resize-SvtDatastore.md)

