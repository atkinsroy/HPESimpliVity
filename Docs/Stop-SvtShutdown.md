---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtShutdown.md
schema: 2.0.0
---

# Stop-SvtShutdown

## SYNOPSIS
Cancel the previous shutdown command for one or more SimpliVity Virtual Appliances

## SYNTAX

```
Stop-SvtShutdown [-HostName] <String> [<CommonParameters>]
```

## DESCRIPTION
Cancels a previously executed shutdown request for one or more SimpliVity Virtual Appliances

This RESTAPI call only works if executed on the local SVA.
So this cmdlet iterates through the specified
hosts and connects to each specified host to sequentially shutdown the local SVA.

Note, once executed, you'll need to reconnect back to a surviving SVA, using Connect-Svt to continue
using the HPE SimpliVity cmdlets.

## EXAMPLES

### EXAMPLE 1
```
Stop-SvtShutdown -HostName Host01
```

## PARAMETERS

### -HostName
Specify the HostName running the SimpliVity Virtual Appliance to cancel the shutdown task on

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.Host
## OUTPUTS

### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtShutdown.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Stop-SvtShutdown.md)

