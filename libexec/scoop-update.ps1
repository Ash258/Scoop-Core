# Usage: scoop update [<OPTIONS>] [<APP>...]
# Summary: Update installed application(s), or scoop itself.
# Help: 'scoop update' updates scoop and all local buckets to the latest version.
# 'scoop update <APP>' updates already installed application to the latest available version.
#
# You can use '*' in place of <APP> to update all applications.
#
# Options:
#   -h, --help                Show help for this command.
#   -f, --force               Force update even when there is not a newer version.
#   -g, --global              Update a globally installed application(s).
#   -i, --independent         Do not install dependencies automatically.
#   -k, --no-cache            Do not use the download cache.
#   -s, --skip                Skip hash validation (use with caution!).
#   -q, --quiet               Hide extraneous messages.

'core', 'depends', 'getopt', 'Helpers', 'manifest', 'Uninstall', 'Update', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = getopt $args 'gfiksq' 'global', 'force', 'independent', 'no-cache', 'skip', 'quiet'

if ($_err) { Stop-ScoopExecution -Message "scoop update: $_err" -ExitCode 2 }

# Flags/Parameters
$Global = $Options.g -or $Options.global
$Force = $Options.f -or $Options.force
$CheckHash = !($Options.s -or $Options.skip)
$UseCache = !($Options.k -or $Options.'no-cache')
$Quiet = $Options.q -or $Options.quiet
$Independent = $Options.i -or $Options.independent

if (!$Applications) {
    if ($Global) { Stop-ScoopExecution -Message 'scoop update: --global option is invalid when <APP> is not specified.' -ExitCode 2 }
    if (!$UseCache) { Stop-ScoopExecution -Message 'scoop update: --no-cache option is invalid when <APP> is not specified.' -ExitCode 2 }

    Update-Scoop
} else {
    if ($Global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed applications' -ExitCode 4 }
    if (is_scoop_outdated) { Update-Scoop }

    $outdatedApplications = @()
    $failedApplications = @()
    $applicationsParam = $Applications # Original users request

    if ($applicationsParam -eq '*') {
        $Applications = applist (installed_apps $false) $false
        if ($Global) { $Applications += applist (installed_apps $true) $true }
    } else {
        $Applications = Confirm-InstallationStatus $applicationsParam -Global:$Global
    }

    if ($Applications) {
        foreach ($_ in $Applications) {
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
            Update-App -App $out[0] -Global:$out[1] -Suggested @{ } -Quiet:$Quiet -Independent:$Independent -SkipCache:(!$UseCache) -SkipHashCheck:(!$CheckHash)
        } catch {
            ++$Problems

            $failedApplications += $out[0]

            $title, $body = $_.Exception.Message -split '\|-'
            if (!$body) { $body = $title }
            Write-UserMessage -Message $body -Err
            debug $_.InvocationInfo
            if ($title -ne 'Ignore' -and ($title -ne $body)) { New-IssuePrompt -Application $out[0] -Bucket $out[2] -Title $title -Body $body }

            continue
        }
    }
}

if ($failedApplications) { Write-UserMessage -Message "These applications failed to update: $($failedApplications -join ', ')" -Err }

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
