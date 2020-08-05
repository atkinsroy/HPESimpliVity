---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Stop-SVTshutdown

## SYNOPSIS
Cancel the previous shutdown command for one or more OmniStack Virtual Controllers

## SYNTAX

```
Stop-SVTshutdown [-HostName] <String[]> [<CommonParameters>]
```

## DESCRIPTION
Cancels a previously executed shutdown request for one or more OmniStack Virtual Controllers

This RESTAPI call only works if executed on the local OVC.
So this cmdlet iterates through the specified 
hosts and connects to each specified host to sequentially shutdown the local OVC.

Note, once executed, you'll need to reconnect back to a surviving OVC, using Connect-SVT to continue
using the HPE SimpliVity cmdlets.

## EXAMPLES

### EXAMPLE 1
```
Stop-SVTshutdown -HostName Host01
```

## PARAMETERS

### -HostName
Specify the HostName running the OmniStack virtual controller to cancel the shutdown task on

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
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
