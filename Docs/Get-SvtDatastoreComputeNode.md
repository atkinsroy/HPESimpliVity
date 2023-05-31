---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtDatastoreComputeNode

## SYNOPSIS
Displays the compute hosts (standard ESXi hosts) that have access to the specified datastore(s)

## SYNTAX

```
Get-SvtDatastoreComputeNode [[-DatastoreName] <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS

## EXAMPLES

### EXAMPLE 1
```
Get-SvtDatastoreComputeNode -DatastoreName DS01
```

Display the compute nodes that have NFS access to the specified datastore

### EXAMPLE 2
```
Get-SvtDatastoreComputeNode
```

Displays all datastores in the Federation and the compute nodes that have NFS access to them

### EXAMPLE 3
```
Get-SvtDatastoreComputeNode -DatastoreName DS01 -Raw
```

Display the compute nodes for the specified datastore in raw JSON from the Simplivity API.

## PARAMETERS

### -DatastoreName
Show compute host information for the specified datastore only

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
### HPE.SimpliVity.Datastore
## OUTPUTS

### HPE.SimpliVity.ComputeNode
## NOTES
Author: Roy Atkins, HPE Services

This command currently works in VMware environments only.
Compute nodes are not supported with Hyper-V

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md)

