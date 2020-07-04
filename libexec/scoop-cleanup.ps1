# Usage: scoop cleanup <app> [options]
# Summary: Cleanup apps by removing old versions
# Help: 'scoop cleanup' cleans Scoop apps by removing old versions.
# 'scoop cleanup <app>' cleans up the old versions of that app if said versions exist.
#
# You can use '*' in place of <app> to cleanup all apps.
#
# Options:
#   -g, --global       Cleanup a globally installed app
#   -k, --cache        Remove outdated download cache

'core', 'manifest', 'buckets', 'Versions', 'getopt', 'help', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'gk' 'global', 'cache'
if ($err) { Write-UserMessage -Message "scoop cleanup: $err" -Err; exit 2 }
$global = $opt.g -or $opt.global
$cache = $opt.k -or $opt.cache

if (!$apps) { Write-UserMessage -Message '<app> missing' -Err; my_usage; exit 1 }

if ($global -and !(is_admin)) { Write-UserMessage -Message 'Admin privileges are required to manipulate with globally installed apps' -Err; exit 4 }

function cleanup($app, $global, $verbose, $cache) {
    $currentVersion = Select-CurrentVersion -AppName $app -Global:$global
    if ($cache) { Join-Path $SCOOP_CACHE_DIRECTORY "$app#*" | Remove-Item -Exclude "$app#$currentVersion#*" }

    $versions = Get-InstalledVersion -AppName $app -Global:$global | Where-Object { $_ -ne $currentVersion }
    if (!$versions) {
        if ($verbose) { Write-UserMessage -Message "$app is already clean" -Success }
        return
    }

    Write-Host "Removing ${app}:" -ForegroundColor Yellow -NoNewLine
    $versions | ForEach-Object {
        $version = $_
        Write-Host " $version" -NoNewLine
        $dir = versiondir $app $version $global
        # unlink all potential old link before doing recursive Remove-Item
        unlink_persist_data $dir
        Remove-Item $dir -ErrorAction Stop -Recurse -Force
    }
    Write-Host ''
}

if ($apps) {
    $verbose = $true
    if ($apps -eq '*') {
        $verbose = $false
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        $apps = Confirm-InstallationStatus $apps -Global:$global
    }

    # $apps is now a list of ($app, $global) tuples
    $apps | ForEach-Object { cleanup @_ $verbose $cache }

    if ($cache) { Join-Path $SCOOP_CACHE_DIRECTORY '*.download' | Remove-Item -ErrorAction Ignore }
    if (!$verbose) { Write-UserMessage -Message 'Everything is shiny now!' -Success }
}

exit 0
