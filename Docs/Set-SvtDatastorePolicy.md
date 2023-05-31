---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtDatastorePolicy.md
schema: 2.0.0
---

# Set-SvtDatastorePolicy

## SYNOPSIS
Sets/changes the backup policy on a HPE SimpliVity Datastore

## SYNTAX

```
Set-SvtDatastorePolicy [-DatastoreName] <String> [-PolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION
A SimpliVity datastore must have a backup policy assigned to it.
A default backup policy
is assigned when a datastore is created.
This command allows you to change the backup
policy for the specified datastore

## EXAMPLES

### EXAMPLE 1
```
Set-SvtDatastorePolicy -DatastoreName ds01 -PolicyName Weekly
```

Assigns a new backup policy to the specified datastore

## PARAMETERS

### -DatastoreName
Apply to specified datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PolicyName
The new backup policy for the specified datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
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

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtDatastorePolicy.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Set-SvtDatastorePolicy.md)

