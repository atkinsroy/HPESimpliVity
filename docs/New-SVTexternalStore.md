---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# New-SVTexternalStore

## SYNOPSIS
Registers a new external datastore with the specified HPE SimpliVity cluster

## SYNTAX

```
New-SVTexternalStore [-ExternalStoreName] <String> [-ClusterName] <String> [-ManagementIP] <String>
 [-Username] <String> [-Userpass] <String> [[-ManagementPort] <Int32>] [[-StoragePort] <Int32>]
 [<CommonParameters>]
```

## DESCRIPTION
Registers an external datastore.
Upon creation, external datastores are associated with a specific
HPE SimpliVity cluster, but are subsequently available to all clusters in the cluster group to which 
the specified cluster is a member.

External stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped 
backups to HPE SimpliVity.
The external datastore must be created and configured appropriately to allow 
the registration to successfully complete.

## EXAMPLES

### EXAMPLE 1
```
New-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ClusterName SVTcluster
    -ManagementIP 192.168.10.202 -Username SVT_service -Userpass Password123
```

Registers a new external datastore called StoreOnce-Data03 with the specified HPE SimpliVity Cluster,
using preconfigured credentials.

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

### -ManagementIP
The IP Address of the external store appliance

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Username
The username associated with the external datastore.
HPE SimpliVity uses this to authenticate and 
access the external datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Userpass
The password for the specified username

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ManagementPort
The management port to use for the external storage appliance

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 9387
Accept pipeline input: False
Accept wildcard characters: False
```

### -StoragePort
The storage port to use for the external storage appliance

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: 9388
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
This command works with HPE SimpliVity 4.0.0 and above

## RELATED LINKS
