---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicyRule.md
schema: 2.0.0
---

# New-SvtPolicyRule

## SYNOPSIS
Create a new backup policy rule in a HPE SimpliVity backup policy

## SYNTAX

### ByWeekDay (Default)
```
New-SvtPolicyRule [-PolicyName] <String> -WeekDay <Array> [-DestinationName <String>] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ReplaceRules] [-ImpactReportOnly] [<CommonParameters>]
```

### ByAllDay
```
New-SvtPolicyRule [-PolicyName] <String> [-All] [-DestinationName <String>] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ReplaceRules] [-ImpactReportOnly] [<CommonParameters>]
```

### ByMonthDay
```
New-SvtPolicyRule [-PolicyName] <String> -MonthDay <Array> [-DestinationName <String>] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ReplaceRules] [-ImpactReportOnly] [<CommonParameters>]
```

### ByLastDay
```
New-SvtPolicyRule [-PolicyName] <String> [-LastDay] [-DestinationName <String>] [-StartTime <String>]
 [-EndTime <String>] [-FrequencyMin <String>] [-RetentionDay <Int32>] [-RetentionHour <Int32>]
 [-ConsistencyType <String>] [-ReplaceRules] [-ImpactReportOnly] [<CommonParameters>]
```

## DESCRIPTION
Create backup policies within an existing HPE SimpliVity backup policy.
Optionally, all the existing 
policy rules can be replaced with the new policy rule.
The destination for backups can be a SimpliVity 
cluster or an appropriately configured external store (HPE StoreOnce Catalyst store).
If no destination 
is specified, the default is the local SimpliVity cluster (shown as "\<Local\>").

You can also display an impact report rather than performing the change.

## EXAMPLES

### EXAMPLE 1
```
New-SvtPolicyRule -PolicyName Silver -All -DestinationName cluster1 -ReplaceRules
```

Replaces all existing backup policy rules with a new rule, backup every day to the specified cluster,
using the default start time (00:00), end time (00:00), Frequency (1440, or once per day), retention of
1 day and no application consistency.

### EXAMPLE 2
```
New-SvtPolicyRule -PolicyName Bronze -Last -ExternalStoreName StoreOnce-Data02 -RetentionDay 365
```

Backup VMs on the last day of the month, storing them on the specified external datastore and retaining the
backup for one year.

PS C:\\\> New-SvtPolicyRule -PolicyName Silver -Weekday Mon,Wed,Fri -DestinationName cluster01 -RetentionDay 7

Adds a new rule to the specified policy to run backups on the specified weekdays and retain backup for a week.

### EXAMPLE 3
```
New-SvtPolicyRule ShortTerm -RetentionHour 4 -FrequencyMin 60 -StartTime 09:00 -EndTime 17:00
```

Add a new rule to a policy called ShortTerm, to backup locally once per hour during office hours and retain the
backup for 4 hours.
(Note: -RetentionHour takes precedence over -RetentionDay if both are specified)

### EXAMPLE 4
```
New-SvtPolicyRule Silver -LastDay -DestinationName Prod -RetentionDay 30 -ConsistencyType VSS
```

Add a new rule to the specified policy to run an application consistent backup on the last day
of each month, retaining it for 1 month.

### EXAMPLE 5
```
New-SvtPolicyRule Silver -All -DestinationName Prod -FrequencyMin 15 -RetentionDay 365 -ImpactReportOnly
```

No changes are made.
Displays an impact report showing the effects that creating this new policy rule would
make to the system.
The report shows projected daily backup rates and total retained backup rates.

## PARAMETERS

### -PolicyName
The backup policy to add/replace backup policy rules

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

### -All
Specifies every day to run backup

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
Specifies the Weekday(s) to run backup, e.g.
"Mon", "Mon,Tue" or "Mon,Wed,Fri"

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
Specifies the day(s) of the month to run backup, e.g.
1 or 1,11,21

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
Specifies the last day of the month to run a backup

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

### -DestinationName
Specifies the destination HPE SimpliVity cluster name or external store name.
If not specified, the
destination will be the local cluster.
If an external store has the same name as a cluster, the cluster
wins.

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

### -StartTime
Specifies the start time (24 hour clock) to run backup, e.g.
22:00

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 00:00
Accept pipeline input: False
Accept wildcard characters: False
```

### -EndTime
Specifies the start time (24 hour clock) to run backup, e.g.
00:00

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 00:00
Accept pipeline input: False
Accept wildcard characters: False
```

### -FrequencyMin
Specifies the frequency, in minutes (how many times a day to run).
Must be between 1 and 1440 minutes (24 hours).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 1440
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionDay
Specifies the retention, in days.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -RetentionHour
Specifies the retention, in hours.
This parameter takes precedence if RetentionDay is also specified.

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

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: NONE
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReplaceRules
If this switch is specified, ALL existing rules in the specified backup policy are removed and replaced with this new rule.

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

### -ImpactReportOnly
Rather than create the policy rule, display a report showing the impact this change would make.
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

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicyRule.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/New-SvtPolicyRule.md)

