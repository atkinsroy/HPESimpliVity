---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVm.md
schema: 2.0.0
---

# Get-SvtVm

## SYNOPSIS
Display information about VMs running on HPE SimpliVity storage

## SYNTAX

### ByVmName (Default)
```
Get-SvtVm [[-VmName] <String[]>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

### ById
```
Get-SvtVm [-VmId <String[]>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

### ByDatastoreName
```
Get-SvtVm [-DatastoreName <String[]>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

### ByClusterName
```
Get-SvtVm [-ClusterName <String[]>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

### ByPolicyName
```
Get-SvtVm [-PolicyName <String>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

### ByHostName
```
Get-SvtVm [-HostName <String>] [-State <String[]>] [-Limit <Int32>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Display information about virtual machines running in the HPE SimpliVity Federation.
Accepts
parameters to limit the objects returned.

Verbose is automatically turned on to show more information about what this command is doing.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtVm
```

Shows all virtual machines in the Federation with state "ALIVE", which is the default state

### EXAMPLE 2
```
Get-SvtVm -VmName Win2019-01
PS C:\> Get-SvtVm -Name Win2019-01
PS C:\> Get-SvtVm Win2019-01
```

All three commands perform the same action - show information about the specified virtual machine(s) with
state "ALIVE", which is the default state

The first command uses the parameter name; the second uses an alias for VmName; the third uses positional
parameter, which accepts a VM name.

### EXAMPLE 3
```
Get-SvtVm -State DELETED
PS C:\> Get-SvtVm -State ALIVE,REMOVED,DELETED
```

Shows all virtual machines in the Federation with the specified state(s)

### EXAMPLE 4
```
Get-SvtVm -DatastoreName DS01,DS02
```

Shows all virtual machines residing on the specified datastore(s)

### EXAMPLE 5
```
Get-SvtVm VM1,VM2,VM3 | Out-GridView -Passthru | Export-CSV FilteredVmList.CSV
```

Exports the specified VM information to Out-GridView to allow filtering and then exports
this to a CSV

### EXAMPLE 6
```
Get-SvtVm -HostName esx04 | Select-Object Name, SizeGB, Policy, HAstatus
```

Show the VMs from the specified host.
Show the selected properties only.

### EXAMPLE 7
```
Get-SvtVM -ClusterName MyCluster -Raw
```

Display the specified VMs in raw JSON from the Simplivity API.

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
## OUTPUTS

### HPE.SimpliVity.VirtualMachine
## NOTES
Author: Roy Atkins, HPE Services

Known issues:
OMNI-69918 - GET calls for virtual machine objects may result in OutOfMemortError when exceeding 8000 objects

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVm.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtVm.md)

