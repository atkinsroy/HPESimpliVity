---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Publish-SVTdatastore

## SYNOPSIS
Adds a share to a HPE SimpliVity datastore for a compute node (a standard ESXi host)

## SYNTAX

```
Publish-SVTdatastore [-DatastoreName] <String> [-ComputeNodeName] <String> [<CommonParameters>]
```

## DESCRIPTION
Adds a share to a HPE SimpliVity datastore for a specified compute node

## EXAMPLES

### EXAMPLE 1
```
Publish-SVTdatastore -DatastoreName DS01 -ComputeNodeName ESXi03
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
This command currently works in VMware environments only.
Compute nodes are not supported with Hyper-V

## RELATED LINKS
