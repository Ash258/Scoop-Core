# Usage: scoop list [query] [options]
# Summary: List installed apps
#
# Help: Lists all installed apps, or the apps matching the supplied query.
#
# Options:
#   -h, --help          Show help for this command.
#   -i, --installed     List apps sorted by installed date.
#   -u, --updated       List apps sorted by update time.
#   -r, --reverse       Apps will be listed descending order.
#                           In case of Installed or Updated, apps will be listed from newest to oldest.

'core', 'buckets', 'getopt', 'Helpers', 'Versions', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $query, $err = getopt $args 'iur' 'installed', 'updated', 'reverse'
if ($err) { Stop-ScoopExecution -Message "scoop install: $err" -ExitCode 2 }

$orderInstalled = $opt.i -or $opt.installed
$orderUpdated = $opt.u -or $opt.updated
$reverse = $opt.r -or $opt.reverse
if ($orderUpdated -and $orderInstalled) { Stop-ScoopExecution -Message '--installed and --updated options cannot be used simultaneously' -ExitCode 2 }
$def_arch = default_architecture

$locA = appsdir $false
$globA = appsdir $true
$local = installed_apps $false | ForEach-Object { @{ 'name' = $_; 'gci' = (Get-ChildItem $locA $_) } }
$global = installed_apps $true | ForEach-Object { @{ 'name' = $_; 'gci' = (Get-ChildItem $globA $_); 'global' = $true } }

$apps = @($local) + @($global)

if ($apps) {
    $mes = if ($query) { " matching '$query'" }
    Write-UserMessage -Message "Installed apps${mes}: `n"

    $sortSplat = @{ 'Property' = { $_.name }; 'Descending' = $reverse }
    if ($orderInstalled) {
        $sortSplat.Property = { $_.gci.CreationTime }
    } elseif ($orderUpdated) {
        $sortSplat.Property = {
            # TODO: Keep only scoop-install
            $old = Join-Path $_.gci.Fullname '*\install.json' | Get-ChildItem
            $new = Join-Path $_.gci.Fullname '*\scoop-install.json' | Get-ChildItem
            @($old, $new) | Get-ChildItem | Sort-Object -Property 'LastWriteTimeUtc' | Select-Object -ExpandProperty 'LastWriteTimeUtc' -Last 1
        }
    }

    $apps | Sort-Object @sortSplat | Where-Object { !$query -or ($_.name -match $query) } | ForEach-Object {
        $app = $_.name
        $global = $_.global
        $ver = Select-CurrentVersion -AppName $app -Global:$global

        $install_info = install_info $app $ver $global
        Write-Host "  $app " -NoNewline
        Write-Host $ver -ForegroundColor 'DarkCyan' -NoNewline

        if ($global) { Write-Host ' *global*' -ForegroundColor 'DarkGreen' -NoNewline }

        if (!$install_info) { Write-Host ' *failed*' -ForegroundColor 'DarkRed' -NoNewline }
        if ($install_info.hold) { Write-Host ' *hold*' -ForegroundColor 'DarkMagenta' -NoNewline }

        if ($install_info.bucket) {
            Write-Host " [$($install_info.bucket)]" -ForegroundColor 'Yellow' -NoNewline
        } elseif ($install_info.url) {
            Write-Host " [$($install_info.url)]" -ForegroundColor 'Yellow' -NoNewline
        }

        if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
            Write-Host " {$($install_info.architecture)}" -ForegroundColor 'DarkRed' -NoNewline
        }
        Write-Host ''
    }
    Write-Host ''
} else {
    Write-userMessage -Message 'No application installed.'
}

exit 0
