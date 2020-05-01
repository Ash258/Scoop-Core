#Requires -Version 5
param($cmd)

Set-StrictMode -Off

'core', 'buckets', 'commands' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$LOG_EXPR = 'git --no-pager log --oneline HEAD -n 1'

if (('--version' -eq $cmd) -or (!$cmd -and ('-v' -in $args))) {
    versiondir 'scoop' 'current' | Push-Location
    Write-UserMessage -Message 'Current Scoop (soon to be Shovel) version:'
    Invoke-Expression $LOG_EXPR
    Write-UserMessage -Message ''
    Pop-Location

    Get-LocalBucket | ForEach-Object {
        Find-BucketDirectory $_ -Root | Push-Location

        if (Test-Path '.git' -PathType Container) {
            Write-UserMessage -Message "'$_' bucket:"
            Invoke-Expression $LOG_EXPR
            Write-UserMessage -Message ''
        }
        Pop-Location
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

exit 0
