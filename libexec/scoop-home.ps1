# Usage: scoop home [<OPTIONS>] <APP>
# Summary: Open the application's homepage in default browser.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'help', 'Helpers', 'getopt', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Options, $Application, $_err = getopt $args

if ($_err) { Stop-ScoopExecution -Message "scoop home: $_err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

# TODO: Adopt Resolve-ManifestInformation
$manifest, $null = find_manifest $Application
if ($manifest) {
    if ([String]::IsNullOrEmpty($manifest.homepage)) {
        Write-UserMessage -Message 'Manifest does not contain homepage property' -Err
        $ExitCode = 3
    } else {
        Start-Process $manifest.homepage
    }
} else {
    Write-UserMessage -Message "Could not find manifest for '$Application'" -Err
    $ExitCode = 3
}

exit $ExitCode
