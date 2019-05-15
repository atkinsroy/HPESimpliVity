# This script creates a report for Daily, weekly, monthly, Old and Latest backups, based on the Expiry date of the backups
# Using -All might be slow. Limited to 500 backups by default; you can increase this to a max of 3000 records using -Limit parameter.

$Daily = (Get-Date).AddDays(1)
$Weekly = (Get-Date).AddDays(7)
$Monthly = (Get-Date).AddDays(28)

Write-Output "Daily Backups"
Get-SvtBackup -All | Where-Object ExpiryDate -le $Daily

Write-Output "Weekly Backups"
Get-SvtBackup -All | Where-Object { $_.ExpiryDate -le $Weekly -and $_.ExpiryDate -gt $Daily }

Write-Output "Monthly Backups"
Get-SvtBackup -All | Where-Object { $_.ExpiryDate -le $Monthly -and $_.ExpiryDate -gt $Weekly }

Write-Output "Older Backups"
Get-SvtBackup -All | Where-Object ExpiryDate -gt $Monthly

Write-Output "Latest Backup for each VM"
Get-SVTBackup -Latest

# Less sexy method. Report based on the policy name
Get-SVTBackup -PolicyName "DailyBackup"
# Or
Get-SVTBackup -All | Where-Object PolicyName -eq "DailyBackup"

