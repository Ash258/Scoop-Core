# Usage: scoop uninstall <app> [options]
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
#
# Options:
#   -g, --global   Uninstall a globally installed app
#   -p, --purge    Remove all persistent data

'core', 'manifest', 'help', 'Helpers', 'install', 'shortcuts', 'psmodules', 'versions', 'getopt', 'uninstall' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'gp' 'global', 'purge'

if ($err) { Stop-ScoopExecution -Message "scoop uninstall: $err" -ExitCode 2 }

$global = $opt.g -or $opt.global
$purge = $opt.p -or $opt.purge

if (!$apps) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }

if ($global -and !(is_admin)) {
    Stop-ScoopExecution -Message 'Administrator privileges are required to uninstall global apps.' -ExitCode 4
}

if ($apps -eq 'scoop') {
    & (Join-Path $PSScriptRoot '..\bin\uninstall.ps1') $global $purge
    exit $LASTEXITCODE
}

$apps = Confirm-InstallationStatus $apps -Global:$global
if (!$apps) {
    Stop-ScoopExecution -Message 'No application to uninstall' -ExitCode 3 -SkipSeverity
}

$exitCode = 0
$problems = 0
# TODO: remove label
:app_loop foreach ($_ in $apps) {
    ($app, $global) = $_

    $result = Uninstall-ScoopApplication -App $app -Global:$global -Purge:$purge -Older
    if ($result -eq $false) {
        ++$problems
        continue
    }

    Write-UserMessage -Message "'$app' was uninstalled." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
