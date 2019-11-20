# This script creates a report for daily, weekly, monthly and Older backups, based on the Expiry date of the backups
# Using -All might be slow. The API will show a maximum of 3000 records, so you might need to filter if you have a larger
# environment.

# Change IP address to match one of your virtual controllers
$IP = 192.168.1.1

# It is assumed you have previously created a credential file, for example:
#Get-Credential -Message 'Enter a password at prompt' -UserName 'administrator@vsphere.local' | Export-Clixml OVCcred.xml
$Cred = Import-Clixml .\OVCcred.xml

# Connect is an OmniStack Virtual Controller in your environment:
Connect-SVT -OVC $IP -Credential $Cred

# For a report suffix
$TimeStamp = Get-Date -Format 'yyMMddhhmm'

# Get the dates we want to report on
$Daily = (Get-Date).AddDays(1)
$Weekly = (Get-Date).AddDays(7)
$Monthly = (Get-Date).AddDays(28)

# Get 'all' backups. This will be limited to 3000 backup objects. To get more objects, 
# you'll need to filter on some other property (see below), and maybe use multiple commands. 
$AllBackup = Get-SVTbackup -All -Verbose

Write-Output 'Daily Backups'
$AllBackup | Where-Object ExpiryDate -le $Daily |
Export-Csv -Path DailyBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Weekly Backups'
$AllBackup | Where-Object {
    $_.ExpiryDate -le $Weekly -and $_.ExpiryDate -gt $Daily
} | Export-Csv -Path WeeklyBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Monthly Backups'
$AllBackup | Where-Object {
    $_.ExpiryDate -le $Monthly -and $_.ExpiryDate -gt $Weekly
} | Export-Csv -Path MonthlyBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Older Backups'
$AllBackup | Where-Object ExpiryDate -gt $Monthly |
Export-Csv -Path OlderBackup-$TimeStamp.csv -NoTypeInformation

Write-Output 'Failed Backups...'
$Failed = $AllBackup | Where-Object BackupState -ne 'PROTECTED'
$FailedCount = ($Failed | Measure-Object).Count
if ($FailedCount -gt 0) {
    Write-Warning "$FailedCount failed backups found"
    $Failed | Export-Csv -Path FailedBackup-$TimeStamp.csv -NoTypeInformation
}
else {
    Write-Output "No failed backups found"
}

# Filtering on a property of the backup object. Some Examples:
# by policy name, for example, how to show more than 3000 backups
# (assumes backups for each policy is less than 3000 backups):
#  AllBackup = Get-SVTBackup -PolicyName "Bronze" -Limit 3000
#  AllBackup += Get-SVTBackup -PolicyName "Silver" -Limit 3000
#  AllBackup += Get-SVTBackup -PoliciyName "Gold" -Limit 3000
# 
# by VM, for example:
#  $Allbackup = Get-SVTBackup -VMname "VM01" -Limit 3000
#
# by data store, for example:
#  $AllBackup = Get-SVTBackup -DataStoreName "DataStore01" -Limit 3000
#
# by cluster, for example:
#  $AllBackup = Get-SVTBackup -ClusterName "Production01" -Limit 3000