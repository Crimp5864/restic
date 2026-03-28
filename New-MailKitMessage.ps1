# Stub script for dev only
param (
    [Parameter(Mandatory=$true)][string]$Subject,
    [Parameter(Mandatory=$true)][string]$TextBody
)

Write-Host "=== MailKit Stub ==="
Write-Host "Subject: $Subject"
Write-Host "Body: $TextBody"
Write-Host "===================="

# Simulate successful execution
exit 0