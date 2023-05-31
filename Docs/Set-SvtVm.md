---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtVm.md
schema: 2.0.0
---

# Set-SvtVm

## SYNOPSIS
Sets a backup policy or the user credentials to enable application consistent backups on HPE SimpliVity
virtual machines.

## SYNTAX

### SetPolicy (Default)
```
Set-SvtVm [-VmName] <String[]> [-PolicyName] <String> [-ImpactReportOnly] [-VmId <String>] [<CommonParameters>]
```

### SetCredential
```
Set-SvtVm [-VmName] <String[]> [-Username] <String> [-Password] <SecureString> [<CommonParameters>]
```

## DESCRIPTION
Either sets a new HPE SimpliVity backup policy on virtual machines or sets the guest user credentials
to enable application consistent backups.
Optionally, for backup policy changes, display an impact report
rather than performing the action.

When a VM is first created, it inherits the backup policy set on the HPE SimpliVity datastore it is
created on.
Use this command to explicitly set a different backup policy for specified virtual machine(s).
Once set (either automatically or manually), a VM will retain the same backup policy, even if it is moved
to another datastore with a different default backup policy.

To create application-consistent backups that use Microsoft Volume Shadow Copy Service (VSS), enter the
guest credentials for one or more virtual machines.
The guest credentials must use administrator
privileges for VSS.
The target virtual machine(s) must be powered on.
The target virtual machine(s) must
be running Microsoft Windows.

The user name can be specified in the following forms:
   "administrator", a local user account
   "domain\svc_backup", an Active Directory domain user account
   "svc_backup@domain.com", Active Directory domain user account

The password cannot be entered as a parameter.
The command will prompt for a secure string to be entered.

## EXAMPLES

### EXAMPLE 1
```
Get-SvtVm -Datastore DS01 | Set-SvtVmPolicy Silver
```

Changes the backup policy for all VMs on the specified datastore to the backup policy named 'Silver'

### EXAMPLE 2
```
Set-SvtVmPolicy Silver VM01
```

Using positional parameters to apply a new backup policy to the VM

### EXAMPLE 3
```
Get-SvtVm -Policy Silver | Set-SvtVmPolicy -PolicyName Gold -ImpactReportOnly
```

No changes are made.
Displays an impact report showing the effects that changing all virtual machines with
the Silver backup policy to the Gold backup policy would make to the system.
The report shows projected
daily backup rates and total retained backup rates.

### EXAMPLE 4
```
Set-SvtVm -VmName MyVm -Username svc_backup
```

Prompts for the password of the specified account and sets the VSS credentials for the virtual machine.

### EXAMPLE 5
```
"VM1", "VM2" | Set-SvtVm -Username twodogs\backupadmin
```

Prompts for the password of the specified account and sets the VSS credentials for the two virtual machines.
The command contacts the running Windows guest to confirm the validity of the password before setting it.

### EXAMPLE 6
```
Get-VM Win2019-01 | Set-SvtVm -Username administrator
PS C:\> Get-VM Win2019-01 | Select-Object VmName, AppAwareVmStatus
```

Set the credentials for the specified virtual machine and then confirm they are set properly.

## PARAMETERS

### -VmName
The target virtual machine(s)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Name

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PolicyName
The name of the new policy to use when setting the backup policy on one or more VMs

```yaml
Type: String
Parameter Sets: SetPolicy
Aliases: Policy

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ImpactReportOnly
Rather than change the backup policy on one or more virtual machines, display a report showing the impact
this action would make.
The report shows projected daily backup rates and new total retained backups given
the frequency and retention settings for the given backup policy.

```yaml
Type: SwitchParameter
Parameter Sets: SetPolicy
Aliases:

Required: False
Position: 3
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -VmId
Instead of specifying one or more VM names, HPE SimpliVity virtual machine objects can be passed in from
the pipeline, using Get-SvtVm.
This is more efficient (single call to the SimpliVity API).

```yaml
Type: String
Parameter Sets: SetPolicy
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Username
When setting the user credentials, specify the username

```yaml
Type: String
Parameter Sets: SetCredential
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
When setting the user credentials, the password must be entered as a secure string (not as a parameter)

```yaml
Type: SecureString
Parameter Sets: SetCredential
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String
### HPE.SimpliVity.VirtualMachine
## OUTPUTS

### HPE.SimpliVity.Task
### System.Management.Automation.PSCustomObject
## NOTES
Author: Roy Atkins, HPE Services

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtVm.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Set-SvtVm.md)

