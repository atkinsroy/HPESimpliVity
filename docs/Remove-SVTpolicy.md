---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Remove-SVTpolicy

## SYNOPSIS
Removes a HPE SimpliVity backup policy

## SYNTAX

```
Remove-SVTpolicy [-PolicyName] <String> [<CommonParameters>]
```

## DESCRIPTION
Removes a HPE SimpliVity backup policy, providing it is not in use be any datastores or virtual machines.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTvm | Select VmName, PolicyName
PS C:\> Get-SVTdatastore | Select DatastoreName, PolicyName
PS C:\> Remove-SVTpolicy -PolicyName Silver
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

## RELATED LINKS
