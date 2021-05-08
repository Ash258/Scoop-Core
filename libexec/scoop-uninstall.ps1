# Usage: scoop uninstall [<OPTIONS>] <APP>...
# Summary: Uninstall specified application(s).
#
# Options:
#   -h, --help     Show help for this command.
#   -g, --global   Uninstall a globally installed application(s).
#   -p, --purge    Persisted data will be removed.
#                  Normally when application is being uninstalled, the data defined in persist property/manually persisted are kept.

'core', 'manifest', 'help', 'Helpers', 'install', 'shortcuts', 'psmodules', 'Versions', 'getopt', 'Uninstall' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'gp' 'global', 'purge'

if ($err) { Stop-ScoopExecution -Message "scoop uninstall: $err" -ExitCode 2 }

$global = $opt.g -or $opt.global
$purge = $opt.p -or $opt.purge

if (!$apps) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

if ($global -and !(is_admin)) {
    Stop-ScoopExecution -Message 'Administrator privileges are required to uninstall globally installed applications.' -ExitCode 4
}

if ($apps -eq 'scoop') {
    & (Join-Path $PSScriptRoot '..\bin\uninstall.ps1') $global $purge
    exit $LASTEXITCODE
}

$apps = Confirm-InstallationStatus $apps -Global:$global
if (!$apps) {
    # This is not strict error
    # Keeping it with zero exit code will allow chaining of commands in such use case (mainly vscode tasks dependencies)
    Stop-ScoopExecution -Message 'No application to uninstall' -ExitCode 0 -SkipSeverity
}

$exitCode = 0
$problems = 0
foreach ($_ in $apps) {
    ($app, $global, $bucket) = $_

    $result = $false
    try {
        $result = Uninstall-ScoopApplication -App $app -Global:$global -Purge:$purge -Older
    } catch {
        ++$problems

        $title, $body = $_.Exception.Message -split '\|-'
        if (!$body) { $body = $title }
        Write-UserMessage -Message $body -Err
        debug $_.InvocationInfo
        if ($title -ne 'Ignore' -and ($title -ne $body)) { New-IssuePrompt -Application $app -Bucket $bucket -Title $title -Body $body }

        continue
    }

    if ($result -eq $false) {
        ++$problems
        continue
    }

    Write-UserMessage -Message "'$app' was uninstalled." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
