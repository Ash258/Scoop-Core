#Requires -Version 5
param($cmd)

Set-StrictMode -Off

'core', 'buckets', 'Helpers', 'commands', 'Git' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias
$exitCode = 0

if (('--version' -eq $cmd) -or (!$cmd -and ('-v' -in $args))) {
    Write-UserMessage -Message 'Current Scoop (soon to be Shovel) version:' -Output
    Invoke-GitCmd -Command 'VersionLog' -Repository (versiondir 'scoop' 'current')
    Write-UserMessage -Message '' -Output

    Get-LocalBucket | ForEach-Object {
        $b = Find-BucketDirectory $_ -Root

        if (Join-Path $b '.git' | Test-Path -PathType Container) {
            Write-UserMessage -Message "'$_' bucket:" -Output
            Invoke-GitCmd -Command 'VersionLog' -Repository $b
            Write-UserMessage -Message '' -Output
        }
    }
} elseif ((@($null, '--help', '/?') -contains $cmd) -or ($args[0] -contains '-h')) {
    Invoke-ScoopCommand 'help' $args
    $exitCode = $LASTEXITCODE
} elseif ((commands) -contains $cmd) {
    Invoke-ScoopCommand $cmd $args
    $exitCode = $LASTEXITCODE
} else {
    Write-UserMessage -Message "scoop: '$cmd' isn't a scoop command. See 'scoop help'." -Output
    $exitCode = 2
}

exit $exitCode
