---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Get-SVTexternalStore

## SYNOPSIS
Displays information on the available external datastores configured in HPE SimpliVity

## SYNTAX

```
Get-SVTexternalStore [[-ExternalStoreName] <String[]>] [<CommonParameters>]
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
Get-SVTexternalStore StoreOnce-Data01,StoreOnce-Data02,StoreOnce-Data03
PS C:\> Get-SVTexternalStore -Name StoreOnce-Data01
```

Display information about the specified external datastore(s)

### EXAMPLE 2
```
Get-SVTexternalStore
```

Displays all external datastores in the Federation

## PARAMETERS

### -ExternalStoreName
Specify the external datastore to display information

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### system.string
## OUTPUTS

### HPE.SimpliVity.Externalstore
## NOTES
This command works with HPE SimpliVity 4.0.0 and above

## RELATED LINKS
