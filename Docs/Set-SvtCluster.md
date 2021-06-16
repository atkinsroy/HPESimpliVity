---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Set-SvtCluster

## SYNOPSIS

Set properties of a HPE SimpliVity cluster

## SYNTAX

### TimeZone (Default)

```PowerShell
Set-SvtCluster [-ClusterName] <String> [-TimeZone] <String> [<CommonParameters>]
```

### EnableIWO

```PowerShell
Set-SvtCluster [-ClusterName] <String> [-EnableIWO] <Boolean> [<CommonParameters>]
```

## DESCRIPTION

Either sets the timezone or enables/disables the Intelligent Workload Optimizer (IWO) on a HPE SimpliVity cluster. Read the product documentation for more information about IWO.

Use 'Get-SvtTimezone' to see a list of valid timezones
Use 'Get-SvtCluster | Select-Object ClusterName,TimeZone' to see the currently set timezone
Use 'Get-SvtCluster | Select-Object ClusterName, IwoEnabled' to see if IWO is currently enabled

## EXAMPLES

### EXAMPLE 1

```PowerShell
Set-SvtCluster -Cluster PROD -Timezone 'Australia/Sydney'
```

Sets the time zone for the specified cluster

### EXAMPLE 2

```PowerShell
Set-SvtCluster -EnableIWO:$true
```

Enables IWO on the specified cluster.
This command requires v4.1.0 or above.

## PARAMETERS

### -ClusterName

Specify the cluster you want to change

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeZone

Specify a valid timezone. Use Get-Timezone to see a list of valid timezones

```yaml
Type: String
Parameter Sets: TimeZone
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableIWO

Specify either $true or $false to enable or disable IWO

```yaml
Type: Boolean
Parameter Sets: EnableIWO
Aliases:

Required: True
Position: 2
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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
