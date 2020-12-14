---
external help file: HPESimpliVity-help.xml
Module Name: hpesimplivity
online version: https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Connect-SVT.md
schema: 2.0.0
---

# Connect-SVT

## SYNOPSIS
Connect to a HPE SimpliVity OmniStack Virtual Controller (OVC) or Managed Virtual Appliance (MVA)

## SYNTAX

```
Connect-SVT [-OVC] <String> [[-Credential] <PSCredential>] [-SignedCert] [<CommonParameters>]
```

## DESCRIPTION
To access the SimpliVity REST API, you need to request an authentication token by issuing a request
using the OAuth authentication method.
Once obtained, you can pass the resulting access token via the
HTTP header using an Authorisation Bearer token.

The access token is stored in a global variable accessible to all HPESimpliVity cmdlets in the PowerShell 
session.
Note that the access token times out after 10 minutes of inactivity.
However, the HPESimpliVity 
module will automatically recreate a new token using cached credentials.

## EXAMPLES

### EXAMPLE 1
```
Connect-SVT -OVC <FQDN or IP Address of OVC>
```

This will securely prompt you for credentials

### EXAMPLE 2
```
$Cred = Get-Credential -Message 'Enter Credentials'
PS C:\> Connect-SVT -OVC <FQDN or IP Address of OVC> -Credential $Cred
```

Create the credential first, then pass it as a parameter.

### EXAMPLE 3
```
$CredFile = "$((Get-Location).Path)\OVCcred.XML"
PS C:\> Get-Credential -Credential '<username@domain>'| Export-CLIXML $CredFile
```

Another way is to store the credential in a file (as above), then connect to the OVC using:
PS C:\\\> Connect-SVT -OVC \<FQDN or IP Address of OVC\> -Credential $(Import-CLIXML $CredFile)

or:
PS C:\\\> $Cred = Import-CLIXML $CredFile
PS C:\\\> Connect-SVT -OVC \<FQDN or IP Address of OVC\> -Credential $Cred

This method is useful in non-interactive sessions.
Once the file is created, run the Connect-SVT
command to connect and reconnect to the OVC, as required.

## PARAMETERS

### -OVC
The Fully Qualified Domain Name (FQDN) or IP address of any OmniStack Virtual Controller (or MVA). 
This is the management IP address of the OVC / MVA.

```yaml
Type: String
Parameter Sets: (All)
Aliases: VirtualController, VC, Name

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
User generated credential as System.Management.Automation.PSCredential.
Use the Get-Credential 
PowerShell cmdlet to create the credential.
This can optionally be imported from a file in cases where 
you are invoking non-interactively.
E.g.
shutting down the OVCs from a script invoked by UPS software.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SignedCert
Requires a trusted certificate to enable TLS1.2.
By default, the cmdlet allows untrusted certificates with 
HTTPS connections.
This is, most commonly, a self-signed certificate.
Alternatively it could be a 
certificate issued from an untrusted certificate authority, such as an internal CA.

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

### System.Management.Automation.PSCustomObject
## NOTES

## RELATED LINKS

[https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Connect-SVT.md](https://github.com/atkinsroy/HPESimpliVity/blob/master/docs/Connect-SVT.md)

