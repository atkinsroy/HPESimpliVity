---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtDatastoreComputeNode.md
schema: 2.0.0
---

# Get-SvtTask

## SYNOPSIS

Show information about tasks that are currently executing or have finished executing in an HPE SimpliVity environment

## SYNTAX

### ByObject (Default)

```PowerShell
Get-SvtTask [[-Task] <Object>] [<CommonParameters>]
```

### ById

```PowerShell
Get-SvtTask [-Id <String>] [<CommonParameters>]
```

## DESCRIPTION

Performing most Post/Delete calls to the SimpliVity REST API will generate task objects as output. Whilst these task objects are immediately returned, the task themselves will change state over time. For example, when a Clone VM task completes, its state changes from IN_PROGRESS to COMPLETED.

All cmdlets that return a JSON 'task' object, (e.g. New-SvtBackup and New-SvtClone) will output custom task objects of type HPE.SimpliVity.Task and can then be used as input here to find out if the task completed successfully.

You can either specify the Task ID from the cmdlet output or, more usefully, use $SvtTask. This is a global variable that all 'task producing' HPE SimpliVity cmdlets create. $SvtTask is overwritten each time one of these cmdlets is executed.

## EXAMPLES

### EXAMPLE 1

```PowerShell
Get-SvtTask
```

Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates a SimpliVity resource

### EXAMPLE 2

```PowerShell
New-SvtBackup -VmName MyVm
PS C:\> Get-SvtTask
```

Show the current state of the task executed from the New-SvtBackup cmdlet.

### EXAMPLE 3

```PowerShell
New-SvtClone Server2016-01 NewServer2016-01
PS C:\> Get-SvtTask | Format-List
```

The first command clones the specified VM. The second command monitors the progress of the clone task, showing all the task properties.

### EXAMPLE 4

```PowerShell
Get-SvtTask -ID d7ef1442-2633-...-a03e69ae24a6
```

Displays the progress of the specified task ID. This command is useful when using the Web console to test REST API calls

## PARAMETERS

### -Task

The task object(s). Uses the global variable $SvtTask which is generated from a 'task producing' HPE SimpliVity cmdlet, like New-SvtBackup, New-SvtClone and Move-SvtVm.

```yaml
Type: Object
Parameter Sets: ByObject
Aliases:

Required: False
Position: 1
Default value: $SvtTask
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Id

Specify a valid task ID

```yaml
Type: String
Parameter Sets: ById
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### HPE.SimpliVity.Task

## OUTPUTS

### HPE.SimpliVity.Task

## NOTES

Author: Roy Atkins, HPE Pointnext Services

## RELATED LINKS
