---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Set-SVTtimezone

## SYNOPSIS
Sets the timezone on a HPE SimpliVity cluster

## SYNTAX

```
Set-SVTtimezone [-ClusterName] <String> [-TimeZone] <String> [<CommonParameters>]
```

## DESCRIPTION
Sets the timezone on a HPE SimpliVity cluster

Use 'Get-SVTtimezone' to see a list of valid timezones
Use 'Get-SVTcluster | Select-Object TimeZone' to see the currently set timezone

## EXAMPLES

### EXAMPLE 1
```
Set-SVTtimezone -Cluster PROD -Timezone 'Australia/Sydney'
```

Sets the time zone for the specified cluster

## PARAMETERS

### -ClusterName
Specify the cluster whose timezone you'd like set

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
Specify the valid timezone.
Use Get-Timezone to see a list of valid timezones

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

## RELATED LINKS
