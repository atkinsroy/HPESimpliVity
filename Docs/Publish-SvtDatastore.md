---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Publish-SvtDatastore.md
schema: 2.0.0
---

# Publish-SvtDatastore

## SYNOPSIS
Adds a share to a HPE SimpliVity datastore for a compute node (a standard ESXi host)

## SYNTAX

```
Publish-SvtDatastore [-DatastoreName] <String> [-ComputeNodeName] <String> [<CommonParameters>]
```

## DESCRIPTION
Adds a share to a HPE SimpliVity datastore for a specified compute node

## EXAMPLES

### EXAMPLE 1
```
Publish-SvtDatastore -DatastoreName DS01 -ComputeNodeName ESXi03
```

The specified compute node is given access to the datastore

## PARAMETERS

### -DatastoreName
The datastore to add a new share to

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

### -ComputeNodeName
The compute node that will have the new share

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

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Publish-SvtDatastore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Publish-SvtDatastore.md)

