---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTvm

## SYNOPSIS
Display information about VMs running on HPE SimpliVity storage

## SYNTAX

### ByVmName (Default)
```
Get-SVTvm [[-VmName] <String[]>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

### ById
```
Get-SVTvm [-VmId <String[]>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

### ByDatastoreName
```
Get-SVTvm [-DatastoreName <String[]>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

### ByClusterName
```
Get-SVTvm [-ClusterName <String[]>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

### ByPolicyName
```
Get-SVTvm [-PolicyName <String>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

### ByHostName
```
Get-SVTvm [-HostName <String>] [-State <String[]>] [-Limit <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Display information about virtual machines running in the HPE SimpliVity Federation.
Accepts
parameters to limit the objects returned.
Also accepts output from Get-SVThost as input.

Verbose is automatically turned on to show more information about what this command is doing.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTvm
```

Shows all virtual machines in the Federation with state "ALIVE", which is the default state

### EXAMPLE 2
```
Get-SVTvm -VmName Server2016-01
PS C:\> Get-SVTvm -Name Server2016-01
PS C:\> Get-SVTvm Server2016-01
```

All three commands perform the same action - show information about the specified virtual machine(s) with 
state "ALIVE", which is the default state

The first command uses the parameter name; the second uses an alias for VmName; the third uses positional
parameter, which accepts a VM name.

### EXAMPLE 3
```
Get-SVTvm -State DELETED
PS C:\> Get-SVTvm -State ALIVE,REMOVED,DELETED
```

Shows all virtual machines in the Federation with the specified state(s)

### EXAMPLE 4
```
Get-SVTvm -DatastoreName DS01,DS02
```

Shows all virtual machines residing on the specified datastore(s)

### EXAMPLE 5
```
Get-SVTvm VM1,VM2,VM3 | Out-GridView -Passthru | Export-CSV FilteredVmList.CSV
```

Exports the specified VM information to Out-GridView to allow filtering and then exports
this to a CSV

### EXAMPLE 6
```
Get-SVTvm -HostName esx04 | Select-Object Name, SizeGB, Policy, HAstatus
```

Show the VMs from the specified host.
Show the selected properties only.

## PARAMETERS

### -VmName
Display information for the specified virtual machine

```yaml
Type: String[]
Parameter Sets: ByVmName
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VmId
Display information for the specified virtual machine ID

```yaml
Type: String[]
Parameter Sets: ById
Aliases: Id

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DatastoreName
Display information for virtual machines on the specified datastore

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

### -ClusterName
Display information for virtual machines on the specified cluster

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

### -PolicyName
Display information for virtual machines that have the specified backup policy assigned

```yaml
Type: String
Parameter Sets: ByPolicyName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HostName
Display information for virtual machines on the specified host

```yaml
Type: String
Parameter Sets: ByHostName
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -State
Display information for virtual machines with the specified state

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ALIVE
Accept pipeline input: False
Accept wildcard characters: False
```

### -Limit
The maximum number of virtual machines to display

```yaml
Type: Int32
Parameter Sets: (All)
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

### HPE.SimpliVity.VirtualMachine
## NOTES
Known issues:
OMNI-69918 - GET calls for virtual machine objects may result in OutOfMemortError when exceeding 8000 objects

## RELATED LINKS
