---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Remove-SVTexternalStore

## SYNOPSIS
Unregisters (removes) an external datastore from the specified HPE SimpliVity cluster

## SYNTAX

```
Remove-SVTexternalStore [-ExternalStoreName] <String> [-ClusterName] <String> [<CommonParameters>]
```

## DESCRIPTION
Unregisters an external datastore.
Removes the external store as a backup destination for the cluster.
Backups remain on the external store, but they can no longer be managed by HPE SimpliVity.

External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped 
backups to HPE SimpliVity.
Once unregistered, the Catalyst store remains on the StoreOnce appliance but
is inaccessible to HPE SimpliVity.

## EXAMPLES

### EXAMPLE 1
```
Remove-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SVTcluster
```

Unregisters (removes) the external datastore called StoreOnce-Data03 from the specified 
HPE SimpliVity Cluster

## PARAMETERS

### -ExternalStoreName
External datastore name.
This is the pre-existing Catalyst store name on HPE StoreOnce

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
The HPE SimpliVity cluster name to associate this external store.
Once created, the external store is
available to all clusters in the cluster group

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

### system.string
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES
This command works with HPE SimpliVity 4.0.1 and above

## RELATED LINKS
