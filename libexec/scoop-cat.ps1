# Usage: scoop cat <app>
# Summary: Show content of specified manifest.

param([Parameter(ValueFromRemainingArguments)] [String[]] $Application)

'help', 'Helpers', 'install', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

if (!$Application) {
    # TODO:? Extend Stop-ScoopExecution with -Usage switch
    Write-UserMessage -Message '<app> missing' -Err
    my_usage
    exit 1
}

$exitCode = 0
$problems = 0
foreach ($app in $Application) {
    Write-UserMessage -Message "Showing manifest for $app" -Color Green

    # Prevent leaking variables from previous iteration
    $cleanAppName = $bucket = $version = $appName = $manifest = $foundBucket = $url = $null

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
        $exitCode = 3
        continue
    }

    if ($manifest) {
        $manifest | ConvertToPrettyJson | Write-UserMessage -Output
    } else {
        Write-UserMessage -Message "Manifest for $app not found" -Err
        ++$problems
        continue
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
