$env:RESTIC_REPOSITORY = "sftp:username@i<local_server>:/restic/$($env:COMPUTERNAME.ToLower())"
$env:RESTIC_PASSWORD_FILE = "password file"
