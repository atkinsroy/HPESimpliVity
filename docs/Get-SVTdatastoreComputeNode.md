---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTdatastoreComputeNode

## SYNOPSIS
Displays the compute hosts (standard ESXi hosts) that have access to the specified datastore(s)

## SYNTAX

```
Get-SVTdatastoreComputeNode [[-DatastoreName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Displays the compute nodes that have been configured to connect to the HPE SimpliVity datastore via NFS

## EXAMPLES

### EXAMPLE 1
```
Get-SVTdatastoreComputeNode -DatastoreName DS01
```

Display the compute nodes that have NFS access to the specified datastore

### EXAMPLE 2
```
Get-SVTdatastoreComputeNode
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
Default value: (Get-SVTdatastore | Select-Object -ExpandProperty DatastoreName)
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### system.string
### HPE.SimpliVity.Datastore
## OUTPUTS

### HPE.SimpliVity.ComputeNode
## NOTES
This command currently works in VMware environments only.
Compute nodes are not supported with Hyper-V

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md)

