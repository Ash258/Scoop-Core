'core', 'manifest', 'install', 'shortcuts', 'psmodules', 'versions' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

# TODO: Refactor
function pre_uninstall($manifest, $arch) {
    $pre = arch_specific 'pre_uninstall' $manifest $arch
    if ($pre) {
        Write-UserMessage -Message 'Running pre-uninstall script...'
        Invoke-Expression (@($pre) -join "`r`n")
    }
}

function post_uninstall($manifest, $arch) {
    $post = arch_specific 'post_uninstall' $manifest $arch
    if ($post) {
        Write-UserMessage -Message 'Running post-uninstall script...'
        Invoke-Expression (@($post) -join "`r`n")
    }
}

function Uninstall-ScoopApplication {
    <#
    .SYNOPSIS
        Uninstall application.
    .PARAMETER App
        Application name to be uninstalled.
    .PARAMETER Global
        Globally installed application.
    .PARAMETER Purge
        Remove persisted data.
    .PARAMETER Older
        Remove older versions. Older versions are removed only on uninstallation, not on update.
    #>
    [CmdletBinding()]
    [OutputType([Bool])]
    param(
        [String] $App,
        [Switch] $Global,
        [Switch] $Purge,
        [Switch] $Older
        # TODO: Force
    )

    # Do not uninstall when there is any process opened from application directory
    $processdir = appdir $App $Global | Resolve-Path | Select-Object -ExpandProperty Path
    $processes = Get-Process | Where-Object { $_.Path -like "$processdir\*" }
    if ($processes) {
        $plPr = pluralize $processes.Count 'Process' 'Processes'
        $plId = pluralize $processes.Count 'ID' 'IDs'
        $plIs = pluralize $processes.Count 'is' 'are'
        Write-UserMessage -Err -Message @(
            'Application is still running!'
            "$plPr with following $plId $plIs blocking uninstallation:"
            ($processes.Id -join ', ')
        )

        return $false
    }

    $version = Select-CurrentVersion -AppName $App -Global:$Global
    $dir = versiondir $App $version $Global
    $persist_dir = persistdir $App $Global

    Write-UserMessage -Message "Uninstalling '$App' ($version)"

    try {
        Test-Path $dir -ErrorAction Stop | Out-Null
    } catch [UnauthorizedAccessException] {
        Write-UserMessage -Message "Access denied: $dir. You might need to restart." -Err
        return $false
    }

    $manifest = installed_manifest $App $version $Global
    $install = install_info $App $version $Global
    $architecture = $install.architecture

    pre_uninstall $manifest $architecture
    run_uninstaller $manifest $architecture $dir
    post_uninstall $manifest $architecture

    rm_shims $manifest $Global $architecture
    rm_startmenu_shortcuts $manifest $Global $architecture

    # If a junction was used during install, that will have been used
    # as the reference directory. Otherwise it will just be the version
    # directory.
    $refdir = unlink_current $dir

    uninstall_psmodule $manifest $refdir $Global
    env_rm_path $manifest $refdir $Global
    env_rm $manifest $Global

    # Remove older versions
    if ($Older) {
        try {
            # unlink all potential old link before doing recursive Remove-Item
            unlink_persist_data $dir
            Remove-Item $dir -Recurse -Force -ErrorAction Stop
        } catch {
            if (Test-Path $dir) {
                Write-UserMessage -Message "Couldn't remove '$(friendly_path $dir)'; it may be in use." -Err
                return $false
            }
        }

        @(Get-InstalledVersion -AppName $App -Global:$Global) | ForEach-Object {
            message "Removing older version ($_)."

            $dir = versiondir $app $_ $Global
            try {
                # unlink all potential old link before doing recursive Remove-Item
                unlink_persist_data $dir
                Remove-Item $dir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-UserMessage -Message "Couldn't remove '$(friendly_path $dir)'; it may be in use." -Err
                return $false
            }
        }

        if (@(Get-InstalledVersion -AppName $App -Global:$Global).Length -eq 0) {
            $appdir = appdir $App $Global
            try {
                # if last install failed, the directory seems to be locked and this
                # will throw an error about the directory not existing
                Remove-Item $appdir -Recurse -Force -ErrorAction Stop
            } catch {
                if ((Test-Path $appdir)) { return $false } # only throw if the dir still exists
            }
        }
    }

    if ($Purge) {
        message 'Removing persisted data.'
        $persist_dir = persistdir $App $Global

        if (Test-Path $persist_dir) {
            try {
                Remove-Item $persist_dir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-UserMessage -Message "Couldn't remove '$(friendly_path $persist_dir)'" -Err
                return $false
            }
        }
        # TODO: System wide purge uninstallation
    }

    return $true
}
