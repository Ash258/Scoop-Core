# Usage: scoop prefix [<OPTIONS>] <APP>
# Summary: Return the location/path of installed application.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'help', 'Helpers', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: getopt adoption
# TODO: Add --global

Reset-Alias

$opt, $app, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop prefix: $err" -ExitCode 2 }
if (!$app) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$exitCode = 0

# TODO: Global switch
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
