---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Rename-SVTpolicy

## SYNOPSIS
Rename a HPE SimpliVity backup policy

## SYNTAX

```
Rename-SVTpolicy [-PolicyName] <String> [-NewPolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION
Rename a HPE SimpliVity backup policy

## EXAMPLES

### EXAMPLE 1
```
Get-SVTpolicy
PS C:\> Rename-SVTpolicy -PolicyName Silver -NewPolicyName Gold
```

The first command confirms the new policy name doesn't exist. 
The second command renames the backup policy as specified.

### EXAMPLE 2
```
Rename-SVTpolicy Silver Gold
```

Renames the backup policy as specified

## PARAMETERS

### -PolicyName
The existing backup policy name

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

### -NewPolicyName
The new name for the backup policy

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES

## RELATED LINKS
