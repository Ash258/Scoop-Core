#Requires -Version 5
param($cmd)

Set-StrictMode -Off

'core', 'buckets', 'commands', 'Git' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

if (('--version' -eq $cmd) -or (!$cmd -and ('-v' -in $args))) {
    Write-UserMessage -Message 'Current Scoop (soon to be Shovel) version:' -Output
    Invoke-GitCmd -Command 'VersionLog' -Repository (versiondir 'scoop' 'current')
    Write-UserMessage -Message ''

    Get-LocalBucket | ForEach-Object {
        $b = Find-BucketDirectory $_ -Root

        if (Join-Path $b '.git' | Test-Path -PathType Container) {
            Write-UserMessage -Message "'$_' bucket:" -Output
            Invoke-GitCmd -Command 'VersionLog' -Repository $b
            Write-UserMessage -Message ''
        }
    }
} elseif ((@($null, '--help', '/?') -contains $cmd) -or ($args[0] -contains '-h')) {
    exec 'help' $args
} elseif ((commands) -contains $cmd) {
    exec $cmd $args
} else {
    # TODO: Stop-ScoopExecution
    Write-UserMessage -Message "scoop: '$cmd' isn't a scoop command. See 'scoop help'."
    exit 1
}
