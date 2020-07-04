# Usage: scoop home <app>
# Summary: Opens the app homepage

param($app)

'core', 'help', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias
$exitCode = 0

if ($app) {
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
} else { my_usage; $exitCode = 1 }

exit $exitCode
