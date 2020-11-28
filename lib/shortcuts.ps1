'core', 'Helpers', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $null -ne $_ } | ForEach-Object {
        $target = [System.IO.Path]::Combine($dir, $_.item(0))
        $target = New-Object System.IO.FileInfo($target)
        $name = $_.item(1)
        $arguments = ''
        $icon = $null
        if ($_.length -ge 3) {
            $arguments = $_.item(2)
        }
        if ($_.length -ge 4) {
            $icon = [System.IO.Path]::Combine($dir, $_.item(3))
            $icon = New-Object System.IO.FileInfo($icon)
        }
        $arguments = (Invoke-VariableSubstitution -Entity $arguments -Substitutes @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
        startmenu_shortcut $target $name $arguments $icon $global
    }
}

function shortcut_folder($global) {
    $base = if ($global) { 'commonstartmenu' } else { 'startmenu' }
    $directory = [System.Environment]::GetFolderPath($base) | Join-Path -ChildPath 'Programs\Scoop Apps'

    return ensure $directory
}

function startmenu_shortcut([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global) {
    $base = "Creating shortcut for $shortcutName ($(fname $target))"
    $baseError = "$base failed:"

    if (!$target.Exists) {
        Write-UserMessage -Message "$baseError Couldn't find $target" -Color DarkRed
        return
    }
    if ($icon -and !$icon.Exists) {
        Write-UserMessage -Message "$baseError Couldn't find icon $icon" -Color DarkRed
        return
    }

    $scoop_startmenu_folder = shortcut_folder $global
    $subdirectory = [System.IO.Path]::GetDirectoryName($shortcutName)
    if ($subdirectory) {
        $subdirectory = ensure $([System.IO.Path]::Combine($scoop_startmenu_folder, $subdirectory))
    }

    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut((Join-Path $scoop_startmenu_folder "$shortcutName.lnk"))
    $wsShell.TargetPath = $target.FullName
    $wsShell.WorkingDirectory = $target.DirectoryName
    if ($arguments) { $wsShell.Arguments = $arguments }
    if ($icon -and $icon.Exists) { $wsShell.IconLocation = $icon.FullName }
    $wsShell.Save()

    Write-UserMessage -Message $base
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global, $arch) {
    @(arch_specific 'shortcuts' $manifest $arch) | Where-Object { $null -ne $_ } | ForEach-Object {
        $name = $_.item(1)
        $shortcut = shortcut_folder $global | Join-Path -ChildPath "$name.lnk"

        Write-UserMessage -Message "Removing shortcut $(friendly_path $shortcut)"

        if (Test-Path $shortcut) { Remove-Item $shortcut }
    }
}
