---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Start-SVTshutdown

## SYNOPSIS
Shutdown a HPE Omnistack Virtual Controller

## SYNTAX

```
Start-SVTshutdown [-HostName] <String> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Ideally, you should only run this command when all the VMs in the cluster
have been shutdown, or if you intend to leave virtual controllers running in the cluster.

This RESTAPI call only works if executed on the local host to the virtual controller.
So this command
connects to the virtual controller on the specified host to shut it down.

Note: Once the shutdown is executed on the specified host, this command will reconnect to another 
operational virtual controller in the Federation, using the same credentials, if there is one.

## EXAMPLES

### EXAMPLE 1
```
Start-SVTshutdown -HostName <Name of SimpliVity host>
```

if not the last operational virtual controller, this command waits for the affected VMs to be HA 
compliant.
If it is the last virtual controller, the shutdown does not wait for HA compliance.

You will be prompted before the shutdown.
If this is the last virtual controller, ensure all virtual 
machines are powered off, otherwise there may be loss of data.

### EXAMPLE 2
```
Start-SVTshutdown -HostName Host01 -Confirm:$false
```

Shutdown the specified virtual controller without confirmation.
If this is the last virtual controller, 
ensure all virtual machines are powered off, otherwise there may be loss of data.

### EXAMPLE 3
```
Start-SVTshutdown -HostName Host01 -WhatIf -Verbose
```

Reports on the shutdown operation, including connecting to the virtual controller, without actually 
performing the shutdown.

## PARAMETERS

### -HostName
Specify the host name running the OmniStack virtual controller to shutdown

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

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS
