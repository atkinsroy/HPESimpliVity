---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Get-SVTmetric

## SYNOPSIS
Display the performance information about the specified HPE SimpliVity resource(s)

## SYNTAX

### Host (Default)
```
Get-SVTmetric [-HostName] <String[]> [[-OffsetHour] <Int32>] [[-Hour] <Int32>] [[-Resolution] <String>]
 [-Chart] [-ChartProperty <String[]>] [<CommonParameters>]
```

### Cluster
```
Get-SVTmetric -ClusterName <String[]> [[-OffsetHour] <Int32>] [[-Hour] <Int32>] [[-Resolution] <String>]
 [-Chart] [-ChartProperty <String[]>] [<CommonParameters>]
```

### VirtualMachine
```
Get-SVTmetric -VmName <String[]> [[-OffsetHour] <Int32>] [[-Hour] <Int32>] [[-Resolution] <String>] [-Chart]
 [-ChartProperty <String[]>] [<CommonParameters>]
```

### SVTobject
```
Get-SVTmetric -SVTobject <Object> [[-OffsetHour] <Int32>] [[-Hour] <Int32>] [[-Resolution] <String>] [-Chart]
 [-ChartProperty <String[]>] [<CommonParameters>]
```

## DESCRIPTION
Displays the performance metrics for one of the following specified HPE SimpliVity resources:
    - Cluster
    - Host
    - VM

In addition, output from the Get-SVTcluster, Get-Host and Get-SVTvm commands is accepted as input.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTmetric -ClusterName Production
```

Shows performance metrics about the specified cluster, using the default hour setting (24 hours) and 
resolution (every hour)

### EXAMPLE 2
```
Get-SVThost | Get-SVTmetric -Hour 1 -Resolution SECOND
```

Shows performance metrics for all hosts in the federation, for every second of the last hour

### EXAMPLE 3
```
Get-SVTvm | Where VmName -match "SQL" | Get-SVTmetric
```

Show performance metrics for every VM that has "SQL" in its name

### EXAMPLE 4
```
Get-SVTcluster -ClusterName DR | Get-SVTmetric -Hour 1440 -Resolution DAY
```

Show daily performance metrics for the last two months for the specified cluster

### EXAMPLE 5
```
Get-SVTvm Vm1,Vm2,Vm3 | Get-Metric -Chart -Verbose
```

Create chart(s) instead of showing the metric data.
Chart files are created in the current folder.
Use filtering when creating charts for virtual machines to avoid creating a lot of charts.

### EXAMPLE 6
```
Get-SVThost -Name MyHost | Get-Metric -Chart | Foreach-Object {Invoke-Item $_}
```

Create a metrics chart for the specified host and immediately display it.
Note that Invoke-Item 
only works with image files when the Desktop Experience Feature is installed (may not be installed 
on some servers)

### EXAMPLE 7
```
Get-SVTmetric -Cluster SVTcluster -Chart -ChartProperty IopsRead,IopsWrite
```

Create a metrics chart for the specified cluster showing only the specified properties.
By default
the last day is shown (-Hour 24) with a resolution of MINUTE (-Resolution MINUTE).

### EXAMPLE 8
```
Get-SVTmetric -Host server1 -Chart -OffsetHour 24
```

Create a chart showing metric information from yesterday (or more correctly, a days worth of information 
prior to the last 24 hours).

## PARAMETERS

### -HostName
Show performance metrics for the specified SimpliVity node(s)

```yaml
Type: String[]
Parameter Sets: Host
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClusterName
Show performance metrics for the specified SimpliVity cluster(s)

```yaml
Type: String[]
Parameter Sets: Cluster
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VmName
Show performance metrics for the specified virtual machine(s) hosted on SimpliVity storage

```yaml
Type: String[]
Parameter Sets: VirtualMachine
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SVTobject
Used to accept input from the pipeline.
Accepts HPESimpliVity objects with a specific type

```yaml
Type: Object
Parameter Sets: SVTobject
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -OffsetHour
Show performance metrics starting from the specified offset (hours from now, default is now)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Hour
Show performance metrics for the specified number of hours (starting from OffsetHour)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 24
Accept pipeline input: False
Accept wildcard characters: False
```

### -Resolution
The resolution in seconds, minutes, hours or days

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: MINUTE
Accept pipeline input: False
Accept wildcard characters: False
```

### -Chart
Create a chart instead of showing performance metrics.
The chart file is saved to the current folder. 
One chart is created for each object (e.g.
cluster, host or VM)

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

### -ChartProperty
Specify the properties (metrics) you'd like to see on the chart.
By default all properties are shown

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: ('IopsRead', 'IopsWrite', 'LatencyRead', 'LatencyWrite',
            'ThroughputRead', 'ThroughputWrite')
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Cluster
### HPE.SimpliVity.Host
### HPE.SimpliVity.VirtualMachine
## OUTPUTS

### HPE.SimpliVity.Metric
## NOTES
With the -Chart parameter, there is a known issue with PowerShell V7.0.1, an exception calling "SaveImage", 
could not load file or assembly when trying to save a chart to a file.
PowerShell V5.1, V7.0.0 and
V7.1.0-Preview3 work as expected.

## RELATED LINKS
