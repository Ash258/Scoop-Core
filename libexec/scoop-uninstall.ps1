# Usage: scoop uninstall [<OPTIONS>] <APP>...
# Summary: Uninstall specified application(s).
#
# Options:
#   -h, --help     Show help for this command.
#   -g, --global   Uninstall a globally installed application(s).
#   -p, --purge    Persisted data will be removed.
#                  Normally when application is being uninstalled, the data defined in persist property/manually persisted are kept.

'core', 'getopt', 'help', 'Helpers', 'install', 'manifest', 'psmodules', 'shortcuts', 'Uninstall', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = getopt $args 'gp' 'global', 'purge'

if ($_err) { Stop-ScoopExecution -Message "scoop uninstall: $_err" -ExitCode 2 }

$Global = $Options.g -or $Options.global
$Purge = $Options.p -or $Options.purge

if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }
if ($Global -and !(is_admin)) { Stop-ScoopExecution -Message 'Administrator privileges are required to uninstall globally installed applications.' -ExitCode 4 }

if ($Applications -eq 'scoop') {
    & (Join-Path $PSScriptRoot '..\bin\uninstall.ps1') $Global $Purge
    exit $LASTEXITCODE
}

$Applications = Confirm-InstallationStatus $Applications -Global:$Global

# This is not strict error
# Keeping it with zero exit code will allow chaining of commands in such use case (mainly vscode tasks dependencies)
if (!$Applications) { Stop-ScoopExecution -Message 'No application to uninstall' -ExitCode 0 -SkipSeverity }

foreach ($explode in $Applications) {
    ($app, $gl, $bucket) = $explode
    $result = $false

    try {
        $result = Uninstall-ScoopApplication -App $app -Global:$gl -Purge:$Purge -Older
    } catch {
        ++$Problems

        $title, $body = $_.Exception.Message -split '\|-'
        if (!$body) { $body = $title }
        Write-UserMessage -Message $body -Err
        debug $_.InvocationInfo
        if ($title -ne 'Ignore' -and ($title -ne $body)) { New-IssuePrompt -Application $app -Bucket $bucket -Title $title -Body $body }

        continue
    }

    if ($result -eq $false) {
        ++$Problems
        continue
    }

    Write-UserMessage -Message "'$app' was uninstalled" -Success
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
