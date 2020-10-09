# Usage: scoop prefix <app> [options]
# Summary: Returns the path to the specified app
#
# Options:
#   -h, --help      Show help for this command.

param($app)

'core', 'help', 'Helpers', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias
$exitCode = 0

if (!$app) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }

# TODO: NO_JUNCTION
$app_path = versiondir $app 'current' $false
if (!(Test-Path $app_path)) { $app_path = versiondir $app 'current' $true }

if (Test-Path $app_path) {
    Write-UserMessage -Message $app_path -Output
} else {
    $exitCode = 3
    Write-UserMessage -Message "Could not find app path for '$app'." -Err
}

exit $exitCode
