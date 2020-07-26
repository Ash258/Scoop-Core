# Usage: scoop cache [rm|show] [app]
# Summary: Show or clear the download cache
# Help: Scoop caches downloads so you don't need to download the same files
# when you uninstall and re-install the same version of an app.
#
# You can use
#   scoop cache show
# to see what's in the cache, and
#   scoop cache rm <app>
# to remove downloads for a specific app.
#
# To clear everything in your cache, use:
#   scoop cache rm *

param($cmd, $app)

. (Join-Path $PSScriptRoot "..\lib\help.ps1")

Reset-Alias

function cacheinfo($file) {
    $app, $version, $url = $file.name -split '#'
    $size = filesize $file.length
    return New-Object PSObject -prop @{ 'app' = $app; 'version' = $version; 'url' = $url; 'size' = $size }
}

function show($app) {
    $files = @(Get-ChildItem $SCOOP_CACHE_DIRECTORY | Where-Object -Property Name -Match "^$app")
    $total_length = ($files | Measure-Object length -sum).sum -as [double]

    $f_app = @{ 'Expression' = { "$($_.app) ($($_.version))" } }
    $f_url = @{ 'Expression' = { $_.url }; 'Alignment' = 'Right' }
    $f_size = @{ 'Expression' = { $_.size }; 'Alignment' = 'Right' }


    $files | ForEach-Object { cacheinfo $_ } | Format-Table $f_size, $f_app, $f_url -AutoSize -HideTableHeaders

    "Total: $($files.length) $(pluralize $files.length 'file' 'files'), $(filesize $total_length)"
}

$exitCode = 0
switch ($cmd) {
    'rm' {
        if (!$app) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }
        Join-Path $SCOOP_CACHE_DIRECTORY "$app#*"| Remove-Item -Force -Recurse
        Join-Path $SCOOP_CACHE_DIRECTORY "$app.txt"| Remove-Item -ErrorAction SilentlyContinue -Force -Recurse
    }
    'show' {
        show $app
    }
    default {
        show
    }
}

exit $exitCode
