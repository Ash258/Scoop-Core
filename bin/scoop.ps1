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
# - -v or --version passed
$version = ($cmd -eq '--version') -or (!$cmd -and ('-v' -in $args))

# Scoop itself help should be shown only if explicitly asked:
# - No version asked
# - No command passed
# - /?, /help,, /h, --help, -h passed
$scoopHelp = !$version -and (!$cmd -or (($cmd -in @($null, '--help', '/?', '/help', '/h')) -or (!$cmd -and ('-h' -in $args))))

# Valid command execution
$validCommand = $cmd -and ($cmd -in (commands))

# Command help should be shown only if:
# - No help for scoop asked
# - $cmd is passed
# - --help, -h is in $args
$commandHelp = !$scoopHelp -and $validCommand -and (('--help' -in $args) -or ('-h' -in $args))

if ($version) {
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
} elseif ($scoopHelp) {
    Invoke-ScoopCommand 'help'
    $exitCode = $LASTEXITCODE
} elseif ($commandHelp) {
    Invoke-ScoopCommand 'help' @{ 'cmd' = $cmd }
    $exitCode = $LASTEXITCODE
} elseif ($validCommand) {
    # Filter out --help and -h to prevent handling them in each command
    # This should never be needed, but just in case to prevent failures of installation, etc
    $newArgs = ($args -notlike '--help') -notlike '-h'

    Invoke-ScoopCommand $cmd $newArgs
    $exitCode = $LASTEXITCODE
} else {
    Write-UserMessage -Message "scoop: '$cmd' isn't a scoop command. See 'scoop help'." -Output
    $exitCode = 2
}

exit $exitCode
