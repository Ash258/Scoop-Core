<#
.SYNOPSIS
    Uninstall ALL scoop applications and scoop itself.
.PARAMETER global
    Global applications will be uninstalled.
.PARAMETER purge
    Persisted data will be deleted.
#>
param(
    [bool] $global,
    [bool] $purge
)

'core', 'install', 'shortcuts', 'Versions', 'manifest', 'uninstall' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

if ($global -and !(is_admin)) {
    # TODO: Stop-ScoopExecution
    Write-UserMessage -Message 'You need admin rights to uninstall globally.' -Err
    exit 1
}

$message = 'This will uninstall Scoop and all the programs that have been installed with Scoop!'
if ($purge) {
    $message = 'This will uninstall Scoop, all the programs that have been installed with Scoop and all persisted data!'
}

Write-UserMessage -Message $message -Warning
$yn = Read-Host 'Are you sure? (yN)'
if ($yn -notlike 'y*') { exit }

$errors = 0

function rm_dir($dir) {
    try {
        Remove-Item $dir -ErrorAction Stop -Recurse -Force
    } catch {
        # TODO: Stop-ScoopExecution
        abort "Couldn't remove $(friendly_path $dir): $_"
    }
}

# Remove all folders (except persist) inside given scoop directory.
function keep_onlypersist($directory) {
    Get-ChildItem $directory -Exclude 'persist' | ForEach-Object { rm_dir $_ }
}

# Run uninstallation for each app if necessary, continuing if there's
# a problem deleting a directory (which is quite likely)
if ($global) {
    installed_apps $true | ForEach-Object { # global apps
        $result = Uninstall-ScoopApplication -App $_ -Global
        if ($result -eq $false) { $errors += 1 }
    }
}

installed_apps $false | ForEach-Object { # local apps
    $result = Uninstall-ScoopApplication -App $_
    if ($result -eq $false) { $errors += 1 }
}

if ($errors -gt 0) { abort 'Not all apps could be deleted. Try again or restart.' }

if ($purge) {
    rm_dir $SCOOP_ROOT_DIRECTORY
    if ($global) { rm_dir $SCOOP_GLOBAL_ROOT_DIRECTORY }
} else {
    keep_onlypersist $SCOOP_ROOT_DIRECTORY
    if ($global) { keep_onlypersist $SCOOP_GLOBAL_ROOT_DIRECTORY }
}

remove_from_path (shimdir $false)
if ($global) { remove_from_path (shimdir $true) }

Write-UserMessage -Message 'Scoop has been uninstalled.' -Success
