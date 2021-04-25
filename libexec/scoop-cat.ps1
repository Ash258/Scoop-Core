# Usage: scoop cat [<OPTIONS>] <APP>...
# Summary: Show content of specified manifest(s).
#
# Options:
#   -h, --help      Show help for this command.

'getopt', 'help', 'Helpers', 'install', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$opt, $Application, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop cat: $err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$exitCode = 0
$problems = 0

foreach ($app in $Application) {
    # Prevent leaking variables from previous iteration
    $cleanAppName = $bucket = $version = $appName = $manifest = $foundBucket = $url = $null

    # TODO: Adopt Resolve-ManifestInformation
    $cleanAppName, $bucket, $version = parse_app $app
    $appName, $manifest, $foundBucket, $url = Find-Manifest $cleanAppName $bucket
    if ($null -eq $bucket) { $bucket = $foundBucket }

    # Handle potential use case, which should not appear, but just in case
    # If parsed name/bucket is not same as the provided one
    if ((!$url) -and (($cleanAppName -ne $appName) -or ($bucket -ne $foundBucket))) {
        debug $bucket
        debug $cleanAppName
        debug $foundBucket
        debug $appName
        Write-UserMessage -Message 'Found application name or bucket is not same as requested' -Err
        ++$problems
        continue
    }

    if ($manifest) {
        Write-UserMessage -Message "Showing manifest for $app" -Color 'Green'

        # TODO: YAML
        $manifest | ConvertToPrettyJson | Write-UserMessage -Output
    } else {
        Write-UserMessage -Message "Manifest for $app not found" -Err
        ++$problems
        continue
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
