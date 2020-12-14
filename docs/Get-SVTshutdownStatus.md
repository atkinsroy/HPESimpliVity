---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTshutdownStatus

## SYNOPSIS
Get the shutdown status of one or more Omnistack Virtual Controllers

## SYNTAX

```
Get-SVTshutdownStatus [[-HostName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION
This RESTAPI call only works if executed on the local host to the OVC.
So this cmdlet
iterates through the specified hosts and connects to each specified host to sequentially get the status.

This RESTAPI call only works if status is 'None' (i.e.
the OVC is responsive), which kind of renders 
the REST API a bit useless.
However, this cmdlet is still useful to identify the unresponsive (i.e shut 
down or shutting down) OVC(s).

Note, because we're connecting to each OVC, the connection token will point to the last OVC we 
successfully connect to.
You may want to reconnect to your preferred OVC again using Connect-SVT.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTshutdownStatus
```

Connect to all OVCs in the Federation and show their shutdown status

### EXAMPLE 2
```
Get-SVTshutdownStatus -HostName <Name of SimpliVity host>
```

### EXAMPLE 3
```
Get-SVThost -Cluster MyCluster | Get-SVTshutdownStatus
```

Shows all shutdown status for all the OVCs in the specified cluster
HostName is passed in from the pipeline, using the property name

### EXAMPLE 4
```
'10.10.57.59','10.10.57.61' | Get-SVTshutdownStatus
```

HostName is passed in them the pipeline by value.
Same as:
Get-SVTshutdownStatus -HostName '10.10.57.59','10.10.57.61'

## PARAMETERS

### -HostName
Show shutdown status for the specified host only

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Host
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS
