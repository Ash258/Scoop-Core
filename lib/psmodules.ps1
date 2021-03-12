'core', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

$SCOOP_MODULE_DIRECTORY = Join-Path $SCOOP_ROOT_DIRECTORY 'modules'
$SCOOP_GLOBAL_MODULE_DIRECTORY = Join-Path $SCOOP_GLOBAL_ROOT_DIRECTORY 'modules'
$modulesdir = $SCOOP_MODULE_DIRECTORY

function install_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    $moduleName = $psmodule.name
    if (!$moduleName) { throw [ScoopException] "Invalid manifest|-The 'name' property is missing from 'psmodule'" } # TerminatingError thrown

    $modules = if ($global) { $SCOOP_GLOBAL_MODULE_DIRECTORY } else { $SCOOP_MODULE_DIRECTORY }
    $modules = Confirm-DirectoryExistence -Path $modules

    ensure_in_psmodulepath $SCOOP_MODULE_DIRECTORY $false
    if ($global) { ensure_in_psmodulepath $SCOOP_GLOBAL_MODULE_DIRECTORY $true }

    $linkFrom = Join-Path $modules $moduleName
    Write-UserMessage -Message "Installing PowerShell module '$moduleName'", "Linking $(friendly_path $linkFrom) => $(friendly_path $dir)"

    if (Test-Path $linkFrom) {
        Write-UserMessage -Message "$(friendly_path $linkFrom) already exists. It will be replaced." -Warning
        $linkFrom = Resolve-Path $linkFrom
        # TODO: Drop comspec
        & "$env:COMSPEC" /c "rmdir `"$linkFrom`""
    }

    # TODO: Drop comspec
    & "$env:COMSPEC" /c "mklink /j `"$linkFrom`" `"$dir`"" | Out-Null
}

function uninstall_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    $moduleName = $psmodule.name
    Write-UserMessage -Message "Uninstalling PowerShell module '$moduleName'."

    $from = if ($global) { $SCOOP_GLOBAL_MODULE_DIRECTORY } else { $SCOOP_MODULE_DIRECTORY }
    $linkFrom = Join-Path $from $moduleName

    if (Test-Path $linkFrom) {
        Write-UserMessage -Message "Removing $(friendly_path $linkFrom)"
        $linkfrom = Resolve-Path $linkFrom
        # TODO: Drop comspec
        & "$env:COMSPEC" /c "rmdir `"$linkFrom`""
    }
}

function ensure_in_psmodulepath($dir, $global) {
    $path = env 'psmodulepath' $global
    if (!$global -and ($null -eq $path)) {
        # Add "default" psmodule path
        $path = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules'
    }

    if ($path -notmatch [System.Text.RegularExpressions.Regex]::Escape($dir)) {
        Write-UserMessage -Message "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) PowerShell module path."

        env 'psmodulepath' $global "$dir;$path" # for future sessions...
        $env:psmodulepath = "$dir;$env:psmodulepath" # for this session
    }
}
