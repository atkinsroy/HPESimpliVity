---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Remove-SvtPolicy

## SYNOPSIS

Removes a HPE SimpliVity backup policy

## SYNTAX

```PowerShell
Remove-SvtPolicy [-PolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION

Removes a HPE SimpliVity backup policy, providing it is not in use be any datastores or virtual machines.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtVm | Select VmName, PolicyName
PS C:\> Get-SvtDatastore | Select DatastoreName, PolicyName
PS C:\> Remove-SvtPolicy -PolicyName Silver
```

Confirm there are no datastores or VMs using the backup policy and then delete it.

## PARAMETERS

### -PolicyName

The policy to delete

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

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
