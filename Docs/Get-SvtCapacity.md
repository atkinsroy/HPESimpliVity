---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCapacity.md
schema: 2.0.0
---

# Get-SvtCapacity

## SYNOPSIS
Display capacity information for the specified SimpliVity host

## SYNTAX

```
Get-SvtCapacity [[-HostName] <String[]>] [[-Hour] <Int32>] [[-Resolution] <String>] [[-OffsetHour] <Int32>]
 [-Chart] [<CommonParameters>]
```

## DESCRIPTION
Displays capacity information for a number of useful metrics, such as free space, used capacity, compression
ratio and efficiency ratio over time for a specified SimpliVity host.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtCapacity MyHost
```

Shows capacity information for the specified host for the last 24 hours

### EXAMPLE 2
```
Get-SvtCapacity -HostName MyHost -Hour 1 -Resolution MINUTE
```

Shows capacity information for the specified host showing every minute for the last hour

### EXAMPLE 3
```
Get-SvtCapacity -Chart
```

Creates a chart for each host in the SimpliVity federation showing the latest (24 hours) capacity details

### EXAMPLE 4
```
Get-SvtCapacity Host1,Host2,Host3
```

Shows capacity information for all hosts in the specified list

## PARAMETERS

### -HostName
The SimpliVity host you want to show capacity information for

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Hour
The range in hours (the duration from the specified point in time)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
Position: 3
Default value: HOUR
Accept pipeline input: False
Accept wildcard characters: False
```

### -OffsetHour
Offset in hours from now

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Chart
Create a chart from capacity information.
If more than one host is passed in, a chart for each host is created

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
### HPESimpliVity.Host
## OUTPUTS

### HPE.SimpliVity.Capacity
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCapacity.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtCapacity.md)

