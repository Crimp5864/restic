#$env:RESTIC_REPOSITORY = "sftp:<username>@<local_server>:/restic/$($env:COMPUTERNAME.ToLower())"
#$env:RESTIC_REPOSITORY = "sftp:<username>@<tailscale_server>:/restic/$($env:COMPUTERNAME.ToLower())"
$env:RESTIC_PASSWORD_FILE = "<password file>"
