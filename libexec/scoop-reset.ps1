# Usage: scoop reset [<OPTIONS>] <APP>...
# Summary: Force binaries/shims, shortcuts, environment variables and persisted data to be re-linked.
# Help: Could be used to resolve conflicts in favor of a particular application(s).
# For example, if you have installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
#
# When there are multiple installed versions of same application, they could be reset/switched also:
#    scoop reset bat@0.16.0 => shims will be relinked to use installed version 0.16.0 of application bat
#    scoop reset bat@0.17.0 => shims will be relinked to use installed version 0.17.0 of application bat
#
# 'scoop list' will show currently resetted/switched version.
#
# You can use '*' in place of <APP> to reset all installed applications.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'manifest', 'help', 'getopt', 'install', 'Versions', 'shortcuts' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: Add --global

Reset-Alias

$opt, $apps, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop reset: $err" -ExitCode 2 }
if (!$apps) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

if ($apps -eq '*') {
    $local = installed_apps $false | ForEach-Object { , @($_, $false) }
    $global = installed_apps $true | ForEach-Object { , @($_, $true) }
    $apps = @($local) + @($global)
}

$exitCode = 0
$problems = 0
foreach ($a in $apps) {
    ($app, $global) = $a

    # TODO: Adopt Resolve-ManifestInformation ???
    $app, $bucket, $version = parse_app $app

    # Skip scoop
    if ($app -eq 'scoop') { continue }

    # Set global flag when running reset command on specific app
    if (($null -eq $global) -and (installed $app $true)) { $global = $true }

    if (!(installed $app)) {
        ++$problems
        Write-UserMessage -Message "'$app' isn't installed" -Err
        continue
    }

    if ($null -eq $version) { $version = Select-CurrentVersion -AppName $app -Global:$global }

    $manifest = installed_manifest $app $version $global
    # if this is null we know the version they're resetting to
    # is not installed
    if ($null -eq $manifest) {
        ++$problems
        Write-UserMessage -Message "'$app ($version)' isn't installed" -Err
        continue
    }

    if ($global -and !(is_admin)) {
        Write-UserMessage -Message "'$app' ($version) is a global app. You need admin rights to reset it. Skipping." -Warning
        ++$problems
        continue
    }

    Write-UserMessage -Message "Resetting $app ($version)."

    $dir = Resolve-Path (versiondir $app $version $global)
    $original_dir = $dir
    $persist_dir = persistdir $app $global

    $install = install_info $app $version $global
    $architecture = $install.architecture

    $dir = link_current $dir
    create_shims $manifest $dir $global $architecture
    create_startmenu_shortcuts $manifest $dir $global $architecture
    env_add_path $manifest $dir $global $architecture
    env_set $manifest $dir $global $architecture

    # unlink all potential old link before re-persisting
    unlink_persist_data $original_dir
    persist_data $manifest $original_dir $persist_dir
    persist_permission $manifest $global
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
