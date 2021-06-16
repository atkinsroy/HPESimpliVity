---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Remove-SvtExternalStore

## SYNOPSIS

Deregister (remove) an external datastore from the specified HPE SimpliVity cluster

## SYNTAX

```PowerShell
Remove-SvtExternalStore [-ExternalStoreName] <String> [-ClusterName] <String> [<CommonParameters>]
```

## DESCRIPTION

Deregister an external datastore. Removes the external store as a backup destination for the cluster.
Backups remain on the external store, but they can no longer be managed by HPE SimpliVity.

External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped backups to HPE SimpliVity. Once deregistered, the Catalyst store remains on the StoreOnce appliance but is inaccessible to HPE SimpliVity.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Remove-SvtExternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SvtCluster
```

Deregister (remove) the external datastore called StoreOnce-Data03 from the specified HPE SimpliVity Cluster

## PARAMETERS

### -ExternalStoreName

External datastore name. This is the pre-existing Catalyst store name on HPE StoreOnce

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

### -ClusterName

The HPE SimpliVity cluster name to associate this external store. Once created, the external store is available to all clusters in the cluster group

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

Author: Roy Atkins, HPE Pointnext Services

This command works with HPE SimpliVity 4.0.1 and above

## RELATED LINKS
