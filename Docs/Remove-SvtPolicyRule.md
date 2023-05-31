---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtPolicyRule.md
schema: 2.0.0
---

# Remove-SvtPolicyRule

## SYNOPSIS
Deletes a backup rule from an existing HPE SimpliVity backup policy

## SYNTAX

```
Remove-SvtPolicyRule [-PolicyName] <String> [-RuleNumber] <String> [-ImpactReportOnly] [<CommonParameters>]
```

## DESCRIPTION
Delete an existing rule from a HPE SimpliVity backup policy.
You must specify the policy name and
the rule number to be removed.

Rule numbers start from 0 and increment by 1.
Use Get-SvtPolicy to identify the rule you want to delete.

You can also display an impact report rather than performing the change.

## EXAMPLES

### EXAMPLE 1
```
Remove-SvtPolicyRule -Policy Gold -RuleNumber 2
```

Removes rule number 2 in the specified backup policy

## PARAMETERS

### -PolicyName
Specify the policy containing the policy rule to delete

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

### -RuleNumber
Specify the number assigned to the policy rule to delete.
Use Get-SvtPolicy to show policy information

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

### -ImpactReportOnly
Rather than remove the policy rule, display a report showing the impact this change would make.
The report
shows projected daily backup rates and new total retained backups given the frequency and retention settings
for the specified backup policy.

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

### HPE.SimpliVity.Task
### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtPolicyRule.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Remove-SvtPolicyRule.md)

