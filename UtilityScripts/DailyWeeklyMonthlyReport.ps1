# This script creates a report for daily, weekly, monthly and failed backups based on the create date of the backups

# It is assumed you have previously created a credential file using something similar to:
#Get-Credential -Message 'Enter a password at prompt' -UserName 'administrator@vsphere.local' | Export-Clixml OVCcred.xml

# It is assumed you have previously installed the HPESimpliVity module from PS Gallery, using:
#Install-Module -Name HPESimpliVity -RequiredVersion 1.1.4

# Connect is an OmniStack Virtual Controller in your environment:
$IP = 192.168.1.1   # change this to match one of your virtual controllers
$Cred = Import-Clixml .\OVCcred.xml
Connect-SVT -OVC $IP -Credential $Cred

$TimeStamp = Get-Date -Format 'yyMMddhhmm'

Write-Output 'Day old Backups...'
Get-SVTbackup -Hour 24 -Limit 3000 | Export-Csv -Path DayOldBackup-$TimeStamp.csv -NoTypeInformation
#Invoke-Item DailyBackup-$TimeStamp.csv

Write-Output 'Week old Backups...'
Get-SVTbackup -Hour (24 * 7) -Limit 3000 | Export-Csv -Path WeekOldBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Month old Backups...'
Get-SVTbackup -Hour (24 * 28) -Limit 3000 | Export-Csv -Path MonthOldBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Failed Backups...'
$Failed = Get-SVTbackup -All | Where-Object BackupState -ne 'PROTECTED'
$FailedCount = ($Failed | Measure-Object).Count
if ($FailedCount -gt 0) {
    Write-Warning "$FailedCount failed backups found"
    $Failed | Export-Csv -Path FailedBackup-$TimeStamp.csv -NoTypeInformation
}
else {
    Write-Output "No failed backups found"
}
