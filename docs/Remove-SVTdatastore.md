---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Remove-SVTdatastore

## SYNOPSIS
Remove an HPE SimpliVity datastore

## SYNTAX

```
Remove-SVTdatastore [-DatastoreName] <String> [<CommonParameters>]
```

## DESCRIPTION
Removes the specified SimpliVity datastore.
The datastore cannot be in use by any virtual machines.

## EXAMPLES

### EXAMPLE 1
```
Remove-SVTdatastore -Datastore DStemp
PS C:\> Get-SVTtask
```

Remove the datastore and monitor the task to ensure it completes successfully.

## PARAMETERS

### -DatastoreName
Specify the datastore to delete

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
