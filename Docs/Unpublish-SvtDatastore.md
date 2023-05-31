---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Unpublish-SvtDatastore.md
schema: 2.0.0
---

# Unpublish-SvtDatastore

## SYNOPSIS
Removes a share from a HPE SimpliVity datastore for a compute node (a standard ESXi host)

## SYNTAX

```
Unpublish-SvtDatastore [-DatastoreName] <String> [-ComputeNodeName] <String> [<CommonParameters>]
```

## DESCRIPTION
Removes a share from a HPE SimpliVity datastore for a specified compute node

## EXAMPLES

### EXAMPLE 1
```
Unpublish-SvtDatastore -DatastoreName DS01 -ComputeNodeName ESXi01
```

The specified compute node will no longer have access to the datastore

## PARAMETERS

### -DatastoreName
The datastore to remove a share from

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

### -ComputeNodeName
The compute node that will no longer have access

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

This command currently works in VMware environments only.
Compute nodes are not supported with Hyper-V

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Unpublish-SvtDatastore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Unpublish-SvtDatastore.md)

