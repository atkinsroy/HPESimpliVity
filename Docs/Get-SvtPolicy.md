---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtPolicy.md
schema: 2.0.0
---

# Get-SvtPolicy

## SYNOPSIS
Display HPE SimpliVity backup policy rule information

## SYNTAX

```
Get-SvtPolicy [[-PolicyName] <String[]>] [[-RuleNumber] <Int32>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Shows the rules of backup policies from the SimpliVity Federation

## EXAMPLES

### EXAMPLE 1
```
Get-SvtPolicy
```

Shows all policy rules for all backup policies

### EXAMPLE 2
```
Get-SvtPolicy -PolicyName Silver, Gold
```

Shows the rules from the specified backup policies

### EXAMPLE 3
```
Get-SvtPolicy | Where RetentionDay -eq 7
```

Show all policy rules that have a 7 day retention

### EXAMPLE 4
```
Get-SvtPolicy -PolicyName Gold -Raw
```

Display the specified policy in raw JSON from the Simplivity API.

## PARAMETERS

### -PolicyName
Display information about the specified backup policy only

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RuleNumber
If a backup policy has multiple rules, more than one object is displayed.
Specify the rule number
to display just that rule.
This is useful when a rule needs to be edited or deleted.

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

### -Raw
Display output as JSON, rather than a formatted PowerShell object.
This parameter might useful in troubleshooting
and maintaining the module.

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
## OUTPUTS

### HPE.SimpliVity.Policy
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtPolicy.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Get-SvtPolicy.md)

