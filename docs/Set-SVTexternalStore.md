---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Get-SVTdatastoreComputeNode.md
schema: 2.0.0
---

# Set-SVTexternalStore

## SYNOPSIS
Updates the IP address and credentials for the external store appliance (HPE StoreOnce)

## SYNTAX

```
Set-SVTexternalStore [-ExternalStoreName] <String> [-ManagementIP] <String> [-Username] <String>
 [-Userpass] <String> [<CommonParameters>]
```

## DESCRIPTION
Updates an existing registered external store with new management IP and credentials.
This command
should be used if the credentials on the StoreOnce appliance are changed.

External Stores are preconfigured Catalyst stores on HPE StoreOnce appliances that provide air gapped 
backups to HPE SimpliVity.

## EXAMPLES

### EXAMPLE 1
```
Set-SVTexternalStore -ExternalstoreName StoreOnce-Data03 -ManagementIP 192.168.10.202 
    -Username SVT_service -Userpass Password123
```

Resets the external datastore credentials and management IP address

## PARAMETERS

### -ExternalStoreName
External datastore name.
This is the pre-existing Catalyst store name on HPE StoreOnce

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

### -ManagementIP
The IP Address of the external store appliance

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Username
The username associated with the external datastore.
HPE SimpliVity uses this to authenticate and 
access the external datastore

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Userpass
The password for the specified username

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### system.string
## OUTPUTS

### HPE.SimpliVity.Task
## NOTES
This command works with HPE SimpliVity 4.0.1 and above

## RELATED LINKS
