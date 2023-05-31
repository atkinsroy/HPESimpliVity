---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtExternalStore.md
schema: 2.0.0
---

# Get-SvtExternalStore

## SYNOPSIS
Displays information on the available external datastores configured in HPE SimpliVity

## SYNTAX

```
Get-SvtExternalStore [[-ExternalStoreName] <String[]>] [-Raw] [<CommonParameters>]
```

## DESCRIPTION
Displays external stores that have been registered.
Upon creation, external datastores are associated
with a specific SimpliVity cluster, but are subsequently available to all clusters in the cluster group
to which the specified cluster is a member.

External Stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped
backups to HPE SimpliVity.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtExternalStore StoreOnce-Data01,StoreOnce-Data02,StoreOnce-Data03
PS C:\> Get-SvtExternalStore -Name StoreOnce-Data01
```

Display information about the specified external datastore(s)

### EXAMPLE 2
```
Get-SvtExternalStore
```

Displays all external datastores in the Federation

### EXAMPLE 3
```
Get-SvtExternalStore StoreOnce-Data01 -Raw
```

Display the specified external datastore in raw JSON from the Simplivity API.

## PARAMETERS

### -ExternalStoreName
Show information for the specified external datastore only

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Raw
Display output as JSON, rather than a formatted PowerShell object.
This parameter might useful in troubleshooting
and maintaining the module.

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

### HPE.SimpliVity.Externalstore
## NOTES
Author: Roy Atkins, HPE Services

This command works with HPE SimpliVity 4.0.0 and above

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtExternalStore.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SvtExternalStore.md)

