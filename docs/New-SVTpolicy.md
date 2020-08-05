---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# New-SVTpolicy

## SYNOPSIS
Create a new HPE SimpliVity backup policy

## SYNTAX

```
New-SVTpolicy [-PolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION
Create a new, empty HPE SimpliVity backup policy.
To create or replace rules for the new backup 
policy, use New-SVTpolicyRule. 

To assign the new backup policy, use Set-SVTdatastorePolicy to assign it to a datastore, or 
Set-SVTvmPolicy to assign it to a virtual machine.

## EXAMPLES

### EXAMPLE 1
```
New-SVTpolicy -Policy Silver
```

Creates a new blank backup policy.
To create or replace rules for the new backup policy, 
use New-SVTpolicyRule.

### EXAMPLE 2
```
New-SVTpolicy Gold
```

Creates a new blank backup policy.
To create or replace rules for the new backup policy, 
use New-SVTpolicyRule.

## PARAMETERS

### -PolicyName
The new backup policy name to create

```yaml
Type: String
Parameter Sets: (All)
Aliases: Name

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
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
