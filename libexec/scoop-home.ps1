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

$Application = $Application[0]
# Home does not need to generate the manifest as homepage will not change
if ($Application -notmatch '^https?://') { $Application = ($Application -split '@')[0] }

$resolved = $null
try {
    $resolved = Resolve-ManifestInformation -ApplicationQuery $Application
} catch {
    $title, $body = $_.Exception.Message -split '\|-'
    if (!$body) { $body = $title }
    Write-UserMessage -Message $body -Err
    debug $_.InvocationInfo

    $ExitCode = 3
}

debug $resolved

if ($ExitCode -eq 0) {
    if ([String]::IsNullOrEmpty($resolved.ManifestObject.homepage)) {
        Write-UserMessage -Message 'Manifest does not contain homepage property' -Err
        $ExitCode = 3
    } else {
        Start-Process $resolved.ManifestObject.homepage
    }
}

exit $ExitCode
