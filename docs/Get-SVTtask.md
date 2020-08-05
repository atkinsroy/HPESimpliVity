---
external help file: HPESimpliVity-help.xml
Module Name: HPESimpliVity
online version:
schema: 2.0.0
---

# Get-SVTtask

## SYNOPSIS
Show information about tasks that are currently executing or have finished executing in an 
HPE SimpliVity environment

## SYNTAX

### ByObject (Default)
```
Get-SVTtask [[-Task] <Object>] [<CommonParameters>]
```

### ById
```
Get-SVTtask [-Id <String>] [<CommonParameters>]
```

## DESCRIPTION
Performing most Post/Delete calls to the SimpliVity REST API will generate task objects as output. Whilst these task objects are immediately returned, the task themselves will change state over time. For example, when a Clone VM task completes, its state changes from IN_PROGRESS to COMPLETED.

All cmdlets that return a JSON 'task' object, (e.g. New-SVTbackup and New-SVTclone) will output custom task objects of type HPE.SimpliVity.Task and can then be used as input here to find out if the task completed successfully. You can either specify the Task ID from the cmdlet output or, more usefully, use $SVTtask. This is a global variable that all 'task producing' HPE SimpliVity cmdlets create. $SVTtask is overwritten each time one of these cmdlets is executed.

## EXAMPLES

### EXAMPLE 1
```
Get-SVTtask
```

Provides an update of the task(s) from the last HPESimpliVity cmdlet that creates, deletes or updates a SimpliVity resource

### EXAMPLE 2
```
New-SVTbackup -VmName MyVm
PS C:\> Get-SVTtask
```

Show the current state of the task executed from the New-SVTbackup cmdlet.

### EXAMPLE 3
```
New-SVTclone Server2016-01 NewServer2016-01
PS C:\> Get-SVTtask | Format-List
```

The first command clones the specified VM.
The second command monitors the progress of the clone task, showing all the task properties.

### EXAMPLE 4
```
Get-SVTtask -ID d7ef1442-2633-...-a03e69ae24a6
```

Displays the progress of the specified task ID. This command is useful when using the Web console to test REST API calls

## PARAMETERS

### -Task
The task object(s). Use the global variable $SVTtask which is generated from a 'task producing' HPE SimpliVity cmdlet, like New-SVTbackup, New-SVTclone and Move-SVTvm.

```yaml
Type: Object
Parameter Sets: ByObject
Aliases:

Required: False
Position: 1
Default value: $SVTtask
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

## RELATED LINKS
