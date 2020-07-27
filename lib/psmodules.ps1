'core', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

$SCOOP_MODULE_DIRECTORY = Join-Path $SCOOP_ROOT_DIRECTORY 'modules'
$modulesdir = $SCOOP_MODULE_DIRECTORY

function install_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    if ($global) { Set-TerminatingError -Title "Ignore|-Installing PowerShell modules globally is not implemented!" }

    $modulesdir = ensure $modulesdir
    ensure_in_psmodulepath $modulesdir $global

    $module_name = $psmodule.name
    if (!$module_name) { Set-TerminatingError -Title "Invalid manifest|-The 'name' property is missing from 'psmodule'." }

    $linkfrom = Join-Path $modulesdir $module_name
    Write-UserMessage -Message "Installing PowerShell module '$module_name'"
    Write-UserMessage -Message "Linking $(friendly_path $linkfrom) => $(friendly_path $dir)"

    if (Test-Path $linkfrom) {
        Write-UserMessage -Message "$(friendly_path $linkfrom) already exists. It will be replaced." -Warning
        $linkfrom = Resolve-Path $linkfrom
        & "$env:COMSPEC" /c "rmdir `"$linkfrom`""
    }

    & "$env:COMSPEC" /c "mklink /j `"$linkfrom`" `"$dir`"" | Out-Null
}

function uninstall_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    $module_name = $psmodule.name
    Write-UserMessage -Message "Uninstalling PowerShell module '$module_name'."

    $linkfrom = Join-Path $modulesdir $module_name
    if (Test-Path $linkfrom) {
        Write-UserMessage -Message "Removing $(friendly_path $linkfrom)"
        $linkfrom = Resolve-Path $linkfrom
        & "$env:COMSPEC" /c "rmdir `"$linkfrom`""
    }
}

function ensure_in_psmodulepath($dir, $global) {
    $path = env 'psmodulepath' $global
    if (!$global -and ($null -eq $path)) {
        $path = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules'
    }

    if ($path -notmatch [System.Text.RegularExpressions.Regex]::Escape($dir)) {
        Write-UserMessage -Message "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) PowerShell module path."

        env 'psmodulepath' $global "$dir;$path" # for future sessions...
        $env:psmodulepath = "$dir;$env:psmodulepath" # for this session
    }
}
