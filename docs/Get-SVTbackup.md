---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Get-SVTbackup

## SYNOPSIS
Display information about HPE SimpliVity backups.

## SYNTAX

### ByVmName (Default)
```
Get-SVTbackup [[-VmName] <String[]>] [-BackupName <String[]>] [-DestinationName <String[]>]
 [-BackupState <String[]>] [-BackupType <String[]>] [-MinSizeMB <Int32>] [-MaxSizeMB <Int32>] [-Date <String>]
 [-CreatedAfter <String>] [-CreatedBefore <String>] [-ExpiresAfter <String>] [-ExpiresBefore <String>]
 [-Hour <String>] [-All] [-Limit <Int32>] [<CommonParameters>]
```

### ByClusterName
```
Get-SVTbackup [-Clustername <String[]>] [-BackupName <String[]>] [-DestinationName <String[]>]
 [-BackupState <String[]>] [-BackupType <String[]>] [-MinSizeMB <Int32>] [-MaxSizeMB <Int32>] [-Date <String>]
 [-CreatedAfter <String>] [-CreatedBefore <String>] [-ExpiresAfter <String>] [-ExpiresBefore <String>]
 [-Hour <String>] [-All] [-Limit <Int32>] [<CommonParameters>]
```

### ByDatastoreName
```
Get-SVTbackup [-DatastoreName <String[]>] [-BackupName <String[]>] [-DestinationName <String[]>]
 [-BackupState <String[]>] [-BackupType <String[]>] [-MinSizeMB <Int32>] [-MaxSizeMB <Int32>] [-Date <String>]
 [-CreatedAfter <String>] [-CreatedBefore <String>] [-ExpiresAfter <String>] [-ExpiresBefore <String>]
 [-Hour <String>] [-All] [-Limit <Int32>] [<CommonParameters>]
```

### ByBackupId
```
Get-SVTbackup [-BackupId <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Show backup information from the HPE SimpliVity Federation.
Without any parameters, SimpliVity backups from 
the last 24 hours are shown, but this can be overridden by specifying the -Hour parameter.

By default the limit is set to show 500 backups, as per the HPE recommended value.
This can be set to a 
maximum of 3000 backups using -Limit.

If -Date is used, it will override any other date related parameter (e.g.
-CreatedAfter, -ExpiresAfter
and -Hour).
The other date related parameters all override -Hour.

-All will display all backups, regardless of limit.
Be careful, this command will take a long time to 
complete because it returns ALL backups.
It does this by calling the SimpliVity API multiple times (using 
an offset value with limit set to 3000).
It is recommended to use other parameter(s) with the -All parameter 
to limit the output.

Multiple values can be used for most parameters, but only when connecting to a Managed Virtual Appliance. 
Multi-value parameters currently fail when connected to an Omnistack Virtual Controller.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTbackup
```

Show the last 24 hours of backups from the SimpliVity Federation.

### EXAMPLE 2
```
Get-SVTbackup -Date 04/04/2020
PS C:\> Get-SVTBackup -Date 04/04/2020 -VmName Server2016-04
```

The first command show all backups from the specified date, up to the default limit of 500 backups.
The second command show all backups from the specified date for a specific virtual machine.

### EXAMPLE 3
```
Get-SVTbackup -CreatedAfter "04/04/2020 10:00am" -CreatedBefore "04/04/2020 02:00pm"
```

Show backups created between the specified dates/times.
(using local date/time format).
Limited to 500 
backups by default.

### EXAMPLE 4
```
Get-SVTbackup -ExpiresAfter "04/04/2020" -ExpiresBefore "05/04/2020" -Limit 100
```

Show backups that will expire between the specified dates/times.
(using local date/time format).
Limited to 
display up to 100 backups.

### EXAMPLE 5
```
Get-SVTbackup -Hour 48 -Limit 1000 | 
    Select-Object VmName, DataStoreName, SentMB, UniqueSizeMB | Format-Table -Autosize
```

Show backups up to 48 hours old and display specific properties.
Limited to display up to 1000 backups.

### EXAMPLE 6
```
Get-SVTbackup -All
```

Shows all backups with no limit.
This command may take a long time to complete because it makes multiple
calls to the SimpliVity API until all backups are returned.
It is recommended to use other parameters 
restrict the number of backups returned.

### EXAMPLE 7
```
Get-SVTbackup -Datastore DS01 -All
```

Shows all backups for the specified Datastore with no upper limit.
This command will take a long time 
to complete.

### EXAMPLE 8
```
Get-SVTbackup -VmName Vm1,Vm2 -BackupName 2020-03-28T16:00+10:00 
PS C:\> Get-SVTbackup -VmName Vm1,Vm2,Vm3 -Hour 2 -Limit 1
```

The first command shows backups for the specified VMs with the specified backup name.
The second command shows the last backup taken within the last 2 hours for each specified VM.
The use of multiple, comma separated values works when connected to a Managed Virtual Appliance only.

### EXAMPLE 9
```
Get-SVTbackup -VMname VM1 -BackupName '2019-04-26T16:00:00+10:00'
```

Display the backup for the specified virtual machine in the specified backup

### EXAMPLE 10
```
Get-SVTbackup -VMname VM1 -BackupName '2019-05-05T00:00:00-04:00' -DestinationName SVTcluster
```

If you have backup policies with more than one rule, further refine the filter by specifying the destination
SimpliVity cluster or external store.

### EXAMPLE 11
```
Get-SVTbackup -Datastore DS01,DS02 -Limit 1000
```

Shows all backups on the specified SimpliVity datastores, up to the specified limit

### EXAMPLE 12
```
Get-SVTbackup -ClusterName cluster1 -Limit 100
PS C:\> Get-SVTbackup -ClusterName cluster1 -Limit 1 -Verbose
```

The first command shows the most recent 100 backups for all VMs located on the specified cluster.
The second command shows a quick way to determine the number of backups on a cluster without showing them
all.
The verbose message will always display the number of backups that meet the command criteria.

### EXAMPLE 13
```
Get-SVTbackup -DestinationName cluster1
```

Show backups located on the specified cluster or external store.

You can specify multiple destinations, but they must all be of the same type.
i.e.
SimpliVity clusters
or external stores.

### EXAMPLE 14
```
Get-SVTbackup -DestinationName StoreOnce-Data02,StoreOnce-Data03 -ExpireAfter 31/12/2020
```

Shows backups on the specified external datastores that will expire after the specified date (using local 
date/time format)

### EXAMPLE 15
```
Get-SVTbackup -BackupState FAILED -Limit 20
```

Show a list of failed backups, limited to 20 backups.

### EXAMPLE 16
```
Get-SVTbackup -Datastore DS01 -BackupType MANUAL
```

Show a list of backups that were manually taken for VMs residing on the specified datastore.

### EXAMPLE 17
```
Get-SVTvm -ClusterName cluster1 | Foreach-Object { Get-SVTbackup -VmName $_.VmName -Limit 1 }
```

Display the latest backup for each VM in the specified SimpliVity cluster.

## PARAMETERS

### -VmName
Show all backups for the specified virtual machine(s).
By default a limit of 500 backups are shown, but
this can be increased.

```yaml
Type: String[]
Parameter Sets: ByVmName
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Clustername
Show all backups sourced from a specified HPE SimpliVity cluster name or names.
By default a limit of 500 
backups are shown, but this can be increased.

```yaml
Type: String[]
Parameter Sets: ByClusterName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DatastoreName
Show all backups sourced from a specified SimpliVity datastore or datastores.
By default a limit of 500 
backups are shown, but this can be increased.

```yaml
Type: String[]
Parameter Sets: ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupId
Show the backup with the specified backup ID only.

```yaml
Type: String[]
Parameter Sets: ByBackupId
Aliases: Id

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupName
Show backups with the specified backup name only.

```yaml
Type: String[]
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases: Name

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DestinationName
Show backups located on the specified destination HPE SimpliVity cluster name or external datastore name.
Multiple destinations can be specified, but they must all be of one type (i.e.
cluster or external store)
By default a limit of 500 backups are shown, but this can be increased.

```yaml
Type: String[]
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupState
Show backups with the specified state.
i.e PROTECTED, FAILED or SAVING

```yaml
Type: String[]
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BackupType
Show backups with the specified type.
i.e.
MANUAL or POLICY

```yaml
Type: String[]
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MinSizeMB
Show backups with the specified minimum size

```yaml
Type: Int32
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxSizeMB
Show backups with the specified maximum size

```yaml
Type: Int32
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Date
Display backups created on the specified date.
This takes precedence over CreatedAfter and CreatedBefore.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CreatedAfter
Display backups created after the specified date.
This parameter is ignored if -Date is also specified.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CreatedBefore
Display backup created before the specified date.
This parameter is ignored if -Date is also specified.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpiresAfter
Display backups that expire after the specified date.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExpiresBefore
Display backup that expire before the specified date.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Hour
Display backups created within the specified last number of hours.
By default, backups from the last 24 hours 
are shown.
This parameter is ignored when any other date related parameter is also specified.

```yaml
Type: String
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -All
Bypass the default 500 record limit (and the upper maximum limit of 3000 records).
When this parameter is 
specified, multiple calls are made to the SimpliVity API using an offset, until all backups are retrieved. 
This can take a long time to complete, so it is recommended to use other parameters, like -VmName or 
-DatastoreName to limit the output to those specific parameters.

```yaml
Type: SwitchParameter
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
By default, display 500 backups.
Limit allows you to specify a value between 1 and 3000.
A limit of 1 is 
useful to use with -Verbose, to quickly show how many backups would be returned with a higher limit.
Limit 
is ignored if -All is specified.

```yaml
Type: Int32
Parameter Sets: ByVmName, ByClusterName, ByDatastoreName
Aliases:

Required: False
Position: Named
Default value: 500
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Backup
## NOTES
Known issues with the REST API Get operations for Backup objects:
* OMNI-53190 REST API Limit recommendation for REST GET backup object calls
* OMNI-46361 REST API GET operations for backup objects and sorting and filtering constraints
* Filtering on a cluster destination also displays external store backups
* This issue applies when connected to Omnistack virtual controllers only. It works as expected when connected to a Managed Virtual Appliance.

## RELATED LINKS
