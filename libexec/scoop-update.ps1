# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   -h, --help                Show help for this command.
#   -f, --force               Force update even when there isn't a newer version.
#   -g, --global              Update a globally installed app.
#   -i, --independent         Don't install dependencies automatically.
#   -k, --no-cache            Don't use the download cache.
#   -s, --skip                Skip hash validation (use with caution!).
#   -q, --quiet               Hide extraneous messages.

'depends', 'Helpers', 'getopt', 'manifest', 'Uninstall', 'Update', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'gfiksq' 'global', 'force', 'independent', 'no-cache', 'skip', 'quiet'
if ($err) { Stop-ScoopExecution -Message "scoop update: $err" -ExitCode 2 }

# Flags/Parameters
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$checkHash = !($opt.s -or $opt.skip)
$useCache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent

$exitCode = 0
if (!$apps) {
    if ($global) { Stop-ScoopExecution -Message 'scoop update: --global option is invalid when <app> is not specified.' -ExitCode 2 }
    if (!$useCache) { Stop-ScoopExecution -Message 'scoop update: --no-cache option is invalid when <app> is not specified.' -ExitCode 2 }

    Update-Scoop
} else {
    if ($global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed apps' -ExitCode 4 }
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
            ($app, $global, $bb) = $_
            $status = app_status $app $global
            $bb = $status.bucket

            if ($force -or $status.outdated) {
                if ($status.hold) {
                    Write-UserMessage "'$app' is held to version $($status.version)"
                } else {
                    $outdatedApplications += applist $app $global $bb
                    $globText = if ($global) { ' (global)' } else { '' }
                    Write-UserMessage -Message "${app}: $($status.version) -> $($status.latest_version)$globText" -Warning -SkipSeverity
                }
            } elseif ($applicationsParam -ne '*') {
                Write-UserMessage -Message "${app}: $($status.version) (latest available version)" -Color 'Green'
            }
        }

        $c = $outdatedApplications.Count
        if ($c -eq 0) {
            Write-UserMessage -Message 'Latest versions for all apps are installed! For more information try ''scoop status''' -Color 'Green'
        } else {
            $a = pluralize $c 'app' 'apps'
            Write-UserMessage -Message "Updating $c outdated ${a}:" -Color 'DarkCyan'
        }
    }

    foreach ($out in $outdatedApplications) {
        try {
            Update-App -App $out[0] -Global:$out[1] -Suggested @{ } -Quiet:$quiet -Independent:$independent -SkipCache:(!$useCache) -SkipHashCheck:(!$checkHash)
        } catch {
            ++$problems

            $title, $body = $_.Exception.Message -split '\|-'
            if (!$body) { $body = $title }
            Write-UserMessage -Message $body -Err
            debug $_.InvocationInfo
            if ($title -ne 'Ignore' -and ($title -ne $body)) { New-IssuePrompt -Application $out[0] -Bucket $out[2] -Title $title -Body $body }

            continue
        }
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
