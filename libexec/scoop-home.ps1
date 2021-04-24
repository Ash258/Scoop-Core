# Usage: scoop home [<OPTIONS>] <APP>
# Summary: Opens the application's homepage in default browser.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'help', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$opt, $app, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop home: $err" -ExitCode 2 }
if (!$app) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

Reset-Alias
$exitCode = 0

if ($app) {
    # TODO: Adopt Resolve-ManifestInformation
    $manifest, $bucket = find_manifest $app
    if ($manifest) {
        if ([String]::IsNullOrEmpty($manifest.homepage)) {
            $exitCode = 3
            Write-UserMessage -Message "Could not find homepage in manifest for '$app'." -Err
        } else {
            Start-Process $manifest.homepage
        }
    } else {
        $exitCode = 3
        Write-UserMessage -Message "Could not find manifest for '$app'." -Err
    }
} else {
    Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage)
}

exit $exitCode
