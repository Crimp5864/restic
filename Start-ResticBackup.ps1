Import-Module -Name BurntToast

function Write-ResticLog {
  # Log to file.
  param([string]$message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $entry = "$timestamp - $message" + [System.Environment]::NewLine
  Add-Content -Path $logFile -Value $entry
}

function Send-Notification {
  # Desktop pop-up notifications.
  New-BurntToastNotification -Text 'Restic encountered an error.'
}

function Invoke-ResticBackup {
  # Perform backup with configured options.
  & restic backup $backupSource @backupOptions | Tee-Object -FilePath $logFile -Append
}

function Invoke-ResticForget {
  # Perform forget and prune with configured options.
  & restic forget @forgetOptions | Tee-Object -FilePath $logFile -Append
}

function Test-ResticLock {
  param (
    [Parameter(Position = 0)]
    [int]$ExitCode,

    [Parameter(Position = 1)]
    [string]$ExitDescription,

    [Parameter(Position = 2)]
    [scriptblock]$OperationFunction
  )

  # Check for stale locks
  if ( $exitCode -eq 11 ) {
    Write-ResticLog "$exitDescription Attempting to unlock."

  & restic unlock
  if ( $LASTEXITCODE -eq 0 ) {
      Write-ResticLog 'Unlock succsessful. Retrying operation'

      # Retry the operation function
      & $operationFunction
      return $LASTEXITCODE
    } else {
      Write-ResticLog 'Unlock failed. Aborting operation.'
      return 1
    }
  }

  return $exitCode
}

$configDir = "$env:APPDATA\restic"
$envFile = "$configDir\env.ps1"
$backupSource = "$env:USERPROFILE"
$excludeFile = "$env:APPDATA\restic\excludes.txt"
$logDir = "$env:LOCALAPPDATA\restic"
$logFile   = "$logDir\restic.log"
$backupOptions = @(
  "--iexclude-file=$excludeFile",
  "--exclude-caches",
  "--verbose=1"
)
$forgetOptions = @(
  "--keep-hourly=24",
  "--keep-daily=14",
  "--keep-weekly=8",
  "--keep-monthly=3",
  "--prune",
  "--verbose=1"
)
$exitCodes = @{
  0    = "Command was successful."
  1    = "Command failed, see command help for more details."
  2    = "Go runtime error."
  3    = "Backup command could not read some source data."
  10   = "Repository does not exist."
  11   = "Failed to lock repository."
  12   = "Wrong password."
  130  = "Restic was interrupted using SIGINT or SIGSTOP."
}

if ( -not ( Test-Path $envFile ) ) {
  Write-ResticLog "Missing env file: $envFile"
  Send-Notification
  exit 1
}
. $envFile

if ( -not ( Test-Path -Path "$logDir" -PathType Container ) ) {
  New-Item -Path "$logDir" -ItemType Directory | Out-Null
}

$repoHost = $env:RESTIC_REPOSITORY -replace '.*@([^:]+):.*', '$1'

$end = (Get-Date).AddSeconds(300)
while ( $true ) {
  if ( Test-Connection -TargetName $repoHost -Count 1 -TimeoutSeconds 2 -Quiet ) {
    break
  } elseif ( (Get-Date) -ge $end ) {
    Send-Notification
    exit 1
  }
  Write-ResticLog 'Waiting for network'
  Start-Sleep -Seconds 5  
}

Invoke-ResticBackup
$backupExitCode = $LASTEXITCODE

Test-ResticLock $backupExitCode $exitCodes[$backupExitCode] { Invoke-ResticBackup }
$backupExitCode = $LASTEXITCODE

Write-ResticLog "Restic backup exited with code ${backupExitCode}: $($exitCodes[$backupExitCode])"

if ( $backupExitCode -eq 0 ) {
  Invoke-ResticForget
  $forgetExitCode = $LASTEXITCODE

  Test-ResticLock $forgetExitCode $exitCodes[$forgetExitCode] { Invoke-ResticForget }

  Write-ResticLog "Restic forget exited with code ${forgetExitCode}: $($exitCodes[$forgetExitCode])"
} else {
  $forgetExitCode = 1
}

if ( $backupExitCode -eq 0 -and $forgetExitCode -eq 0 ) {
  $parameters = @{
    Subject = "$env:COMPUTERNAME - Restic has completed successfully"
    TextBody = "Restic exited with code 0: Command was successful."
    }
  & $PSScriptRoot\New-MailKitMessage.ps1 @parameters
  $host.SetShouldExit(0)
} else {
  $parameters = @{
    Subject  = "$env:COMPUTERNAME - Restic encountered an error"
    TextBody = "Restic backup exit code: ${backupExitCode}: $($exitCodes[$backupExitCode]). Restic forget exit code: ${forgetExitCode}: $($exitCodes[$forgetExitCode])."
  }
  & $PSScriptRoot\New-MailKitMessage.ps1 @parameters
  Send-Notification
  exit 1
}
