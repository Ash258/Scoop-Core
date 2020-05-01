# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   -f, --force               Force update even when there isn't a newer version
#   -g, --global              Update a globally installed app
#   -i, --independent         Don't install dependencies automatically
#   -k, --no-cache            Don't use the download cache
#   -s, --skip                Skip hash validation (use with caution!)
#   -q, --quiet               Hide extraneous messages

'core', 'shortcuts', 'psmodules', 'decompress', 'manifest', 'buckets', 'versions', 'getopt', 'depends', 'git', 'install',
'uninstall', 'Update' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$opt, $apps, $err = getopt $args 'gfiksq' 'global', 'force', 'independent', 'no-cache', 'skip', 'quiet'
# TODO: Stop-ScoopExecution
if ($err) { Write-UserMessage -Message "scoop update: $err"; exit 1 }

# Flags/Parameters
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$checkHash = !($opt.s -or $opt.skip)
$useCache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent

if (!$apps) {
    # TODO: Stop-ScoopExecution
    if ($global) { Write-UserMessage -Message 'scoop update: --global is invalid when <app> is not specified.'; exit 1 }
    if (!$useCache) { Write-UserMessage -Message 'scoop update: --no-cache is invalid when <app> is not specified.'; exit 1 }

    Update-Scoop
} else {
    # TODO: Stop-ScoopExecution
    if ($global -and !(is_admin)) { Write-UserMessage -Message 'You need admin rights to update global apps.' -Err; exit 1 }

    if (is_scoop_outdated) { Update-Scoop }
    $outdatedApplications = @()
    $applicationsParam = $apps

    if ($applicationsParam -eq '*') {
        $apps = applist (installed_apps $false) $false
        if ($global) { $apps += applist (installed_apps $true) $true }
    } else {
        $apps = Confirm-InstallationStatus $applicationsParam -Global:$global
    }

    if ($apps) {
        foreach ($_ in $apps) {
            ($app, $global) = $_
            $status = app_status $app $global
            if ($force -or $status.outdated) {
                if ($status.hold) {
                    Write-UserMessage "'$app' is held to version $($status.version)"
                } else {
                    $outdatedApplications += applist $app $global
                    $globText = if ($global) { ' (global)' } else { '' }
                    Write-UserMessage -Message "${app}: $($status.version) -> $($status.latest_version)$globText" -Warning -SkipSeverity
                }
            } elseif ($applicationsParam -ne '*') {
                Write-UserMessage -Message "${app}: $($status.version) (latest available version)" -Color Green
            }
        }

        if ($outdatedApplications -and (Test-Aria2Enabled)) {
            Write-UserMessage -Message 'Scoop uses ''aria2c'' for multi-conneciton downloads.',
                'In case of issues with downloading, run ''scoop config aria2-enabled $false'' to disable aria2.' -Warning
        }

        $c = $outdatedApplications.Count
        if ($c -eq 0) {
            Write-UserMessage -Message 'Latest versions for all apps are installed! For more information try ''scoop status''' -Color Green
        } else {
            $a = pluralize $c 'app' 'apps'
            Write-UserMessage -Message "Updating $c outdated ${a}:" -Color DarkCyan
        }
    }

    foreach ($_ in $outdatedApplications) {
        # TODO: Try catch
        # $outdated is a list of ($app, $global) tuples
        Update-App -App $_[0] -Global:$_[1] -Suggested @{} -Quiet:$quiet -Independent:$independent -SkipCache:(!$useCache) -SkipHashCheck:(!$checkHash)
    }
}

exit 0
