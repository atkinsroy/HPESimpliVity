---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtDatastore.md
schema: 2.0.0
---

# New-SvtDatastore

## SYNOPSIS
Create a new HPE SimpliVity datastore

## SYNTAX

```
New-SvtDatastore [-DatastoreName] <String> [-ClusterName] <String> [-PolicyName] <String> [-SizeGB] <Int32>
 [-SingleReplica] [<CommonParameters>]
```

## DESCRIPTION
Creates a new datastore on the specified SimpliVity cluster.
An existing backup
policy must be assigned when creating a datastore.
The datastore size can be between
1GB and 1,048,576 GB (1,024TB)

## EXAMPLES

### EXAMPLE 1
```
New-SvtDatastore -DatastoreName ds01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 102400
```

Creates a new 100TB datastore called ds01 on Cluster1 and assigns the pre-existing Daily backup policy to it

### EXAMPLE 2
```
New-SvtDatastore -DatastoreName sr01 -ClusterName Cluster1 -PolicyName Daily -SizeGB 200 -SingleReplica
```

Creates a new 200GB single replica datastore called sr01.

## PARAMETERS

### -DatastoreName
Specify the name of the new datastore

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
Specify the cluster of the new datastore

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

### -PolicyName
Specify the existing backup policy to assign to the new datastore

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

### -SizeGB
Specify the size of the new datastore in GB

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -SingleReplica
Specifies that the new datastore will be a single replica datastore (i.e.
no high availability).
This
type of datastore is typically used where application based replication or HA is available.
This parameter
requires V4.1.0 or above.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: False
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

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtDatastore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtDatastore.md)

