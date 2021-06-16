---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtShutdownStatus

## SYNOPSIS

Get the shutdown status of one or more SimpliVity Virtual Appliances

## SYNTAX

```PowerShell
Get-SvtShutdownStatus [[-HostName] <String[]>] [<CommonParameters>]
```

## DESCRIPTION

This cmdlet iterates through the specified hosts and connects to each SVA sequentially.

The RESTAPI call only works if status is 'None' (i.e. the SVA is responsive). However, this cmdlet is still useful to identify the unresponsive SVAs (i.e shut down or shutting down).

Note, the RESTAPI only supports confirmation of the local SVA, so the cmdlet must connecting to each SVA. The connection token will therefore point to the last SVA we successfully connect to. You may want to reconnect to your preferred SVA again using Connect-Svt.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtShutdownStatus
```

Connect to all SVAs in the Federation and show their shutdown status

### EXAMPLE 2

```PowerShell
Get-SvtShutdownStatus -HostName <Name of SimpliVity host>
```

### EXAMPLE 3

```PowerShell
Get-SvtHost -Cluster MyCluster | Get-SvtShutdownStatus
```

Shows all shutdown status for all the SVAs in the specified cluster
HostName is passed in from the pipeline, using the property name

### EXAMPLE 4

```PowerShell
'10.10.57.59','10.10.57.61' | Get-SvtShutdownStatus
```

HostName is passed in them the pipeline by value.
Same as:
Get-SvtShutdownStatus -HostName '10.10.57.59','10.10.57.61'

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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
