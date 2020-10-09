#Requires -Version 5
param([string] $cmd)

Set-StrictMode -Off

'core', 'buckets', 'Helpers', 'commands', 'Git' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0
# Powershell automatically bind bash like short parameters as $args, and does not put it in $cmd parameter

# ONLY if:
# - No command passed
# - -v and --version passed
$version = ($cmd -eq '--version') -or (!$cmd -and ('-v' -in $args))
Write-Host "Vesion:       ", $version

# Scoop itself help should be shown only if explicitly asked:
# - No version asked
# - No command passed
# - /?, /help,, /h, --help, -h passed
$scoopHelp = !$version -and (!$cmd -or (($cmd -in @($null, '--help', '/?', '/help', '/h')) -or (!$cmd -and ('-h' -in $args))))
Write-Host "Scoop:        ", $scoopHelp

# Valid command execution
$validCommand = $cmd -and ($cmd -in (commands))
Write-Host "Command:      ", $validCommand

# Command help should be shown only if:
# - No help for scoop asked
# - $cmd is passed
# - --help, -h is in $args
$commandHelp = !$scoopHelp -and $validCommand -and (('--help' -in $args) -or ('-h' -in $args))
Write-Host "Command Help: ", $commandHelp

if ($version) {
    Write-Host 'SHOWING VERSION' -f magenta
} elseif ($scoopHelp) {
    Write-Host 'SHOWING SCOOP' -f magenta
} elseif ($commandHelp) {
    Write-Host 'SHOWING COMMAND HELP' -f magenta
} elseif ($validCommand) {
    Write-Host 'SHOWING COMMAND' -f magenta
} else {
    Write-Host 'RECOVERING' -f magenta
}
exit 0

if (('--version' -eq $cmd) -or (!$cmd -and ('-v' -in $args))) {
    Write-UserMessage -Message 'Current Scoop (Shovel) version:' -Output
    Invoke-GitCmd -Command 'VersionLog' -Repository (versiondir 'scoop' 'current')
    Write-UserMessage -Message '' -Output

    # TODO: Export to lib/buckets
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
