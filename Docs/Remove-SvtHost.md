---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtHost.md
schema: 2.0.0
---

# Remove-SvtHost

## SYNOPSIS
Removes a HPE SimpliVity node from the cluster/federation

## SYNTAX

```
Remove-SvtHost [-HostName] <String> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Removes a HPE SimpliVity node from the cluster/federation.
Once this command is executed, the specified
node must be factory reset and can then be redeployed using the Deployment Manager.
This command is
equivalent GUI command "Remove from federation"

If there are any virtual machines running on the node or if the node is not HA-compliant, this command
will fail.
You can specify the force command, but be aware that this could cause data loss.

## EXAMPLES

### EXAMPLE 1
```
Remove-SvtHost -HostName Host01
```

Removes the node from the federation providing there are no VMs running and providing the
node is HA-compliant.

### EXAMPLE 2
```
Remove-SvtHost -HostName Host01 -Force
```

Forcibly removes the host from the federation.
This command may cause data loss

### EXAMPLE 3
```
Remove-SvtHost -HostName Host01 -WhatIf
```

This command provides a report on the intended action only, without actually performing the host removal.

## PARAMETERS

### -HostName
Specify the node to remove.

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

### -Force
Forces removal of the node from the HPE SimpliVity federation.
THIS CAN CAUSE DATA LOSS.
If there is one
node left in the cluster, this parameter must be specified (removes HA compliance for any VMs in the
affected cluster.)

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
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

[https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtHost.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/Docs/Remove-SvtHost.md)

