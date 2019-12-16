# This script creates a report for daily, weekly, monthly and Older backups, based on the Expiry date of the backups
# Using -All might be slow. The API will show a maximum of 3000 records, so you might need to filter if you have a larger
# environment.

# Change IP address to match one of your virtual controllers
#$IP = 192.168.1.1

# It is assumed you have previously created a credential file using, for example:
#Get-Credential -Message 'Enter a password at prompt' -UserName 'administrator@vsphere.local' | Export-Clixml OVCcred.xml
#$Cred = Import-Clixml .\OVCcred.xml

# Connect is an OmniStack Virtual Controller in your environment:
#Connect-SVT -OVC $IP -Credential $Cred

# For a report suffix
$TimeStamp = Get-Date -Format 'yyMMddhhmm'

# Initialize variables
$DailyBackup = @()
$WeeklyBackup = @()
$MonthlyBackup = @()
$OldBackup = @()
$culture = (Get-Culture).DateTimeFormat
$LocalDate = "$($culture.ShortDatePattern)" -creplace '^d/', 'dd/' -creplace '^M/', 'MM/' -creplace '/d/', '/dd/'
$LocalTime = "$($culture.LongTimePattern)" -creplace '^h:mm', 'hh:mm' -creplace '^H:mm', 'HH:mm'
$LocalFormat = "$LocalDate $LocalTime"

# Get the dates we want to report on - days in advance of today, because we're interested in the future expiry of backups
$Daily = (Get-Date).AddDays(1)
$Weekly = (Get-Date).AddDays(7) 
$Monthly = (Get-Date).AddDays(28)

# Get 'all' backups. This example will be limited to 3000 backup objects. So, if you have more than 3000 backup 
# objects in the federation, you'll need to filter on a property (by backupName, datastore, cluster or VM, see below) 
# and then iterate, ensuring that each call returns less than 3000 backup objects)
$AllBackup = Get-SVTbackup -All


# For comparison, dates in PowerShell must be "region-neutral", meaning US format.
# But Get-SVTbackup stores dates as strings honouring the local culture. So to compare with Get-Date, the expiry 
# date must be parsed to convert it to a "region-neutral" date.
$AllBackup | ForEach-Object {
    $ExpiryDate = [datetime]::parse($_.ExpiryDate)
    if ($ExpiryDate -le $Daily) {
        #"$ExpiryDate is less than $Daily (Daily)"
        $DailyBackup += $_
    }
    Elseif ($ExpiryDate -gt $Daily -and $ExpiryDate -le $Weekly) {
        #"$ExpiryDate is greater than $Daily and less than $Weekly (Weekly)"
        $WeeklyBackup += $_
    }
    Elseif ($ExpiryDate -gt $Weekly -and $ExpiryDate -le $Monthly) {
        #"$ExpiryDate is greater than $Weekly and less than $Monthly (Monthly)"
        $MonthlyBackup += $_
    }
    Else {
        #"$ExpiryDate is greater $Monthly (Old)"
        $OldBackup += $_
    }
}
# Report on Failed backups
$Failed = $AllBackup | Where-Object BackupState -ne 'PROTECTED'



# Write each collection out to a CSV
$DailyBackup | Sort-Object { $_.ExpiryDate -as [datetime] } -Descending | Export-Csv -NoTypeInformation -Path BackupDailyReport-$TimeStamp.CSV
$WeeklyBackup | Sort-Object { $_.ExpiryDate -as [datetime] } -Descending | Export-Csv -NoTypeInformation -Path BackupWeeklyReport-$TimeStamp.CSV
$MonthlyBackup | Sort-Object { $_.ExpiryDate -as [datetime] } -Descending | Export-Csv -NoTypeInformation -Path BackupMonthlyReport-$TimeStamp.CSV
$OldBackup | Sort-Object { $_.ExpiryDate -as [datetime] } -Descending | Export-Csv -NoTypeInformation -Path BackupLongTermReport-$TimeStamp.CSV
If ($Failed) {
    $Failed | Sort-Object { $_.ExpiryDate -as [datetime] } -Descending | Export-Csv -NoTypeInformation -Path BackupFailedReport-$TimeStamp.CSV
}

# Write a summary report to the console, with report names for reference.
"-" * 60 + "`n  Summary Report:"
"Daily backups, (Expiry date less than 1 day): $($DailyBackup.Count)"
"Weekly backups, (Expiry date between 1 and 7 days): $($WeeklyBackup.Count)"
"Monthly backups, (Expiry date between 7 and 28 days): $($MonthlyBackup.Count)"
"Long Term backups, (Expiry date older than 28 days): $($OldBackup.Count)"
"Failed backups: $($Failed.Count)"
"-" * 60
Get-ChildItem Backup*Report-$TimeStamp.CSV

# Some examples when you have more than 3000 backups in the federation. In each case, you should end up with
# a full list of backups providing each filtered call to Get-SVTbackup returns less than 3000 backup objects.
 
# Without "hardcoding" the filter property, for example, by each datastore:
#  Get-SVTdatastore | Foreach-Object {
#   [array]$AllBackup += Get-SVTBackup -DatastoreName $_ -Limit 3000
#  }

# by hardcoded data store, for example:
#  $AllBackup = Get-SVTBackup -DataStoreName "DataStore01" -Limit 3000
#  $AllBackup += Get-SVTBackup -DataStoreName "DataStore02" -Limit 3000

# by hardcoded VM, for example:
#  $AllBackup = Get-SVTBackup -VMname "VM01" -Limit 3000
#  $AllBackup += Get-SVTBackup -VMname "VM02" -Limit 3000

# by hardcoded cluster, for example:
#  $AllBackup = Get-SVTBackup -ClusterName "Production01" -Limit 3000
#  $AllBackup += Get-SVTBackup -ClusterName "DR01" -Limit 3000
