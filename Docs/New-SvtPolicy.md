---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicy.md
schema: 2.0.0
---

# New-SvtPolicy

## SYNOPSIS
Create a new HPE SimpliVity backup policy

## SYNTAX

```
New-SvtPolicy [-PolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION
Create a new, empty HPE SimpliVity backup policy.
To create or replace rules for the new backup
policy, use New-SvtPolicyRule.

To assign the new backup policy, use Set-SvtDatastorePolicy to assign it to a datastore, or
Set-SvtVmPolicy to assign it to a virtual machine.

## EXAMPLES

### EXAMPLE 1
```
New-SvtPolicy -Policy Silver
```

Creates a new blank backup policy.
To create or replace rules for the new backup policy,
use New-SvtPolicyRule.

### EXAMPLE 2
```
New-SvtPolicy Gold
```

Creates a new blank backup policy.
To create or replace rules for the new backup policy,
use New-SvtPolicyRule.

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
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicy.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicy.md)

