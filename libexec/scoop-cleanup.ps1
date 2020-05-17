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

'core', 'manifest', 'buckets', 'versions', 'getopt', 'help', 'install' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$opt, $apps, $err = getopt $args 'gk' 'global', 'cache'
if ($err) { "scoop cleanup: $err"; exit 1 }
$global = $opt.g -or $opt.global
$cache = $opt.k -or $opt.cache

if (!$apps) { Write-UserMessage -Message 'ERROR: <app> missing' -Err; my_usage; exit 1 }

if ($global -and !(is_admin)) { Write-UserMessage -Message 'ERROR: you need admin rights to cleanup global apps' -Err; exit 1 }

function cleanup($app, $global, $verbose, $cache) {
    $currentVersion = Select-CurrentVerison -AppName $app -Global:$global
    if ($cache) { Remove-Item "$cachedir\$app#*" -Exclude "$app#$currentVersion#*" }

    $versions = Get-InstalledVersion -AppName $app -Global:$global | Where-Object { $_ -ne $currentVersion }
    if (!$versions) {
        if ($verbose) { Write-UserMessage -Message "$app is already clean" -Success }
        return
    }

    Write-Host -f yellow "Removing $app`:" -nonewline
    $versions | ForEach-Object {
        $version = $_
        Write-Host " $version" -nonewline
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

    if ($cache) { Remove-Item "$cachedir\*.download" -ErrorAction Ignore }

    if (!$verbose) { Write-UserMessage -Message 'Everything is shiny now!' -Success }
}

exit 0
