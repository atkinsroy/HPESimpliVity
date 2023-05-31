---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Update-SvtPolicyRule.md
schema: 2.0.0
---

# Update-SvtPolicyRule

## SYNOPSIS
Updates an existing HPE SimpliVity backup policy rule

## SYNTAX

### ByWeekDay (Default)
```
Update-SvtPolicyRule [-PolicyName] <String> [-RuleNumber] <String> -WeekDay <Array> [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ImpactReportOnly] [<CommonParameters>]
```

### ByAllDay
```
Update-SvtPolicyRule [-PolicyName] <String> [-RuleNumber] <String> [-All] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ImpactReportOnly] [<CommonParameters>]
```

### ByMonthDay
```
Update-SvtPolicyRule [-PolicyName] <String> [-RuleNumber] <String> -MonthDay <Array> [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ImpactReportOnly] [<CommonParameters>]
```

### ByLastDay
```
Update-SvtPolicyRule [-PolicyName] <String> [-RuleNumber] <String> [-LastDay] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ImpactReportOnly] [<CommonParameters>]
```

## DESCRIPTION
Updates an existing HPE SimpliVity backup policy rule.
You must specify at least:

- the name of policy to update
- the existing policy rule number
- the required day (via -All, -Weekday, -Monthday or -Lastday), even if you're not changing the day

All other parameters are optional, if not set the new policy rule will inherit the current policy
rule settings.

Note: A backup destination cannot be changed in a rule.
You must first delete the rule and then recreate
it using Remove-SvtPolicyRule and New-SvtPolicyRule respectively, to update the backup destination.

Rule numbers start from 0 and increment by 1.
Use Get-SvtPolicy to identify the rule you want to update.

You can also display an impact report rather than performing the change.

## EXAMPLES

### EXAMPLE 1
```
Update-SvtPolicyRule -Policy Gold -RuleNumber 2 -Weekday Sun,Fri -StartTime 20:00 -EndTime 23:00
```

Updates rule number 2 in the specified policy with a new weekday policy.
start and finish times.
This command
inherits the existing retention, frequency, and application consistency settings from the existing rule.

### EXAMPLE 2
```
Update-SvtPolicyRule -Policy Bronze -RuleNumber 1 -LastDay
PS C:\> Update-SvtPolicyRule Bronze 1 -LastDay
```

Both commands update rule 1 in the specified policy with a new day.
All other settings are inherited from
the existing backup policy rule.

### EXAMPLE 3
```
Update-SvtPolicyRule Silver 3 -MonthDay 1,7,14,21 -RetentionDay 30
```

Updates the existing rule 3 in the specified policy to perform backups four times a month on the specified
days and retains the backup for 30 days.

### EXAMPLE 4
```
Update-SvtPolicyRule Gold 1 -All -RetentionHour 1 -FrequencyMin 20 -StartTime 9:00 -EndTime 17:00
```

Updates the existing rule 1 in the Gold policy to backup 3 times per hour every day during office hours and
retain each backup for 1 hour.
(Note: -RetentionHour takes precedence over -RetentionDay if both are
specified).

### EXAMPLE 5
```
Update-SvtPolicyRule Silver 2 -All -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly
```

No changes are made.
Displays an impact report showing the effects that updating this policy rule would
make to the system.
The report shows projected daily backup rates and total retained backup rates.

## PARAMETERS

### -PolicyName
The name of the backup policy to update

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
The number of the policy rule to update.
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

### -All
Specifies every day to run the backup

```yaml
Type: SwitchParameter
Parameter Sets: ByAllDay
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WeekDay
Specify the Weekday(s) to run the backup, e.g.
Mon, Mon,Tue or Mon,Wed,Fri

```yaml
Type: Array
Parameter Sets: ByWeekDay
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MonthDay
Specify the day(s) of the month to run the backup, e.g.
1, 1,16 or 2,4,6,8,10,12,14,16,18,20,22,24,26,28

```yaml
Type: Array
Parameter Sets: ByMonthDay
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LastDay
Specifies the last day of the month to run the backup

```yaml
Type: SwitchParameter
Parameter Sets: ByLastDay
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartTime
Specifies the start time (24 hour clock) to run backup, e.g.
22:00
If not set, the existing policy rule setting is used

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndTime
Specifies the start time (24 hour clock) to run backup, e.g.
00:00
If not set, the existing policy rule setting is used

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FrequencyMin
Specifies the frequency, in minutes (how many times a day to run).
Must be between 1 and 1440 minutes (24 hours).
If not set, the existing policy rule setting is used

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionDay
Specifies the backup retention, in days.
If not set, the existing policy rule setting is used

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionHour
Specifies the backup retention, in hours.
This parameter takes precedence if RetentionDay is also specified.
If not set, the existing policy rule setting is used

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConsistencyType
Available options are:
1.
NONE - This is the default and creates a crash consistent backup
2.
DEFAULT - Create application consistent backups using VMware Snapshot
3.
VSS - Create application consistent backups using Microsoft VSS in the guest operating system.
Refer
   to the admin guide for requirements and supported applications

If not set, the existing policy rule setting is used

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpactReportOnly
Rather than update the policy rule, display a report showing the impact this change would make.
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

- Changing the destination is not supported.
- Replacing all policy rules is not supported.
Use New-SvtPolicyRule instead.
- Changing ConsistencyType to anything other than None or Default doesn't appear to work.
- Changing ConsistencyType to anything other than None or Default doesn't appear to work.
- Changing ConsistencyType to anything other than None or Default doesn't appear to work.
- Use Remove-SvtPolicyRule and New-SvtPolicyRule to update ConsistencyType to VSS.

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Update-SvtPolicyRule.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Update-SvtPolicyRule.md)

