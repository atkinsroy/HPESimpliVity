---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtDatastoreComputeNode

## SYNOPSIS

Displays the compute hosts (standard ESXi hosts) that have access to the specified datastore(s)

## SYNTAX

```PowerShell
Get-SvtDatastoreComputeNode [[-DatastoreName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtDatastoreComputeNode -DatastoreName DS01
```

Display the compute nodes that have NFS access to the specified datastore

### EXAMPLE 2

```PowerShell
Get-SvtDatastoreComputeNode
```

Displays all datastores in the Federation and the compute nodes that have NFS access to them

## PARAMETERS

### -DatastoreName

Specify the datastore to display information for

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-SvtDatastore | Select-Object -ExpandProperty DatastoreName)
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

### HPE.SimpliVity.Datastore

## OUTPUTS

### HPE.SimpliVity.ComputeNode

## NOTES

Author: Roy Atkins, HPE Pointnext Services

This command currently works in VMware environments only. Compute nodes are not supported with Hyper-V

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md)
