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

# TODO: Remove
$check_hash = $checkHash
$use_cache = $useCache










function update($app, $global, $quiet = $false, $independent, $suggested, $use_cache = $true, $check_hash = $true) {
    $old_version = current_version $app $global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global

    # re-use architecture, bucket and url from first install
    $architecture = ensure_architecture $install.architecture
    $url = $install.url
    $bucket = $install.bucket
    if ($null -eq $bucket) {
        $bucket = 'main'
    }

    if (!$independent) {
        # check dependencies
        $man = if ($url) { $url } else { $app }
        $deps = @(deps $man $architecture) | Where-Object { !(installed $_) }
        $deps | ForEach-Object { install_app $_ $architecture $global $suggested $use_cache $check_hash }
    }

    $version = latest_version $app $bucket $url
    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $(get-date) $quiet
        $check_hash = $false
    }

    if (!$force -and ($old_version -eq $version)) {
        if (!$quiet) {
            warn "The latest version of '$app' ($version) is already installed."
        }
        return
    }
    if (!$version) {
        # installed from a custom bucket/no longer supported
        error "No manifest available for '$app'."
        return
    }

    $manifest = manifest $app $bucket $url

    write-host "Updating '$app' ($old_version -> $version)"

    #region Workaround of #2220
    # Remove and replace whole region after proper fix
    Write-Host "Downloading new version"
    if (Test-Aria2Enabled) {
        dl_with_cache_aria2 $app $version $manifest $architecture $cachedir $manifest.cookie $true $check_hash
    } else {
        $urls = url $manifest $architecture

        foreach ($url in $urls) {
            dl_with_cache $app $version $url $null $manifest.cookie $true

            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $source = fullpath (cache_path $app $version $url)
                $ok, $err = check_hash $source $manifest_hash $(show_app $app $bucket)

                if (!$ok) {
                    error $err
                    if (test-path $source) {
                        # rm cached file
                        Remove-Item -force $source
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket "hash check failed")
                }
            }
        }
    }
    # There is no need to check hash again while installing
    $check_hash = $false
    #endregion Workaround of #2220

    $result = Uninstall-ScoopApplication -App $app -Global:$global
    if ($result -eq $false) { return }

    # Rename current version to .old if same version is installed
    if ($force -and ($old_version -eq $version)) {
        $dir = versiondir $app $old_version $global

        if (!(Test-Path "$dir/../_$version.old")) {
            Move-Item "$dir" "$dir/../_$version.old"
        } else {
            $i = 1
            While (Test-Path "$dir/../_$version.old($i)") {
                $i++
            }
            Move-Item "$dir" "$dir/../_$version.old($i)"
        }
    }

    if ($install.url) {
        $app = $install.url
    } elseif ($bucket) {
        $app = "$bucket/$app"
    }

    install_app $app $architecture $global $suggested $use_cache $check_hash
}

if (!$apps) {
    # TODO: Stop-ScoopExecution
    if ($global) { Write-UserMessage -Message 'scoop update: --global is invalid when <app> is not specified.'; exit 1 }
    if (!$use_cache) { Write-UserMessage -Message "scoop update: --no-cache is invalid when <app> is not specified."; exit 1 }
    Update-Scoop
} else {
    if ($global -and !(is_admin)) { Write-UserMessage -Message 'You need admin rights to update global apps.' -Error; exit 1 }

    if (is_scoop_outdated) { Update-Scoop }
    $outdatedApplications = @()
    $outdated = $outdatedApplications
    $applicationsParam = $apps

    if ($applicationsParam -eq '*') {
        $apps = applist (installed_apps $false) $false
        if ($global) { $apps += applist (installed_apps $true) $true }
    } else {
        $apps = Confirm-InstallationStatus $apps_param -Global:$global
    }

    if ($apps) {
        $apps | ForEach-Object {
            ($app, $global) = $_
            $status = app_status $app $global
            if ($force -or $status.outdated) {
                if(!$status.hold) {
                    $outdated += applist $app $global
                    write-host -f yellow ("$app`: $($status.version) -> $($status.latest_version){0}" -f ('',' (global)')[$global])
                } else {
                    warn "'$app' is held to version $($status.version)"
                }
            } elseif ($apps_param -ne '*') {
                write-host -f green "$app`: $($status.version) (latest version)"
            }
        }

        if ($outdated -and (Test-Aria2Enabled)) {
            warn "Scoop uses 'aria2c' for multi-connection downloads."
            warn "Should it cause issues, run 'scoop config aria2-enabled false' to disable it."
        }
        if ($outdated.Length -gt 1) {
            write-host -f DarkCyan "Updating $($outdated.Length) outdated apps:"
        } elseif ($outdated.Length -eq 0) {
            write-host -f Green "Latest versions for all apps are installed! For more information try 'scoop status'"
        } else {
            write-host -f DarkCyan "Updating one outdated app:"
        }
    }

    $suggested = @{};
    # $outdated is a list of ($app, $global) tuples
    $outdated | ForEach-Object { update @_ $quiet $independent $suggested $use_cache $check_hash }
}

exit 0
