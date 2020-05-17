# Usage: scoop list [query] [options]
# Summary: List installed apps
#
# Help: Lists all installed apps, or the apps matching the supplied query.
#
# Options:
#   -i, --installed     List apps sorted by installed date
#   -u, --updated       List apps sorted by update time
#   -r, --reverse       Apps will be listed descending order.
#                           In case of Installed or Updated, apps will be listed from newest to oldest.

'core', 'buckets', 'getopt', 'versions', 'manifest' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$opt, $query, $err = getopt $args 'iur' 'installed', 'updated', 'reverse'
# TODO: Stop-ScoopExecution
if ($err) { "scoop install: $err"; exit 1 }

$orderInstalled = $opt.i -or $opt.installed
$orderUpdated = $opt.u -or $opt.updated
$reverse = $opt.r -or $opt.reverse
# TODO: Stop-ScoopExecution
if ($orderUpdated -and $orderInstalled) { Write-UserMessage -Message '--installed and --updated parameters cannot be used simultaneously' -Err; exit 1 }
$def_arch = default_architecture

$locA = appsdir $false
$globA = appsdir $true
$local = installed_apps $false | ForEach-Object { @{ name = $_; gci = (Get-ChildItem $locA $_) } }
$global = installed_apps $true | ForEach-Object { @{ name = $_; gci = (Get-ChildItem $globA $_); global = $true } }

$apps = @($local) + @($global)

if ($apps) {
    $mes = if ($query) { " matching '$query'" }
    Write-Host "Installed apps${mes}: `n"

    $sortSplat = @{ 'Property' = { $_.name }; 'Descending' = $reverse }
    if ($orderInstalled) {
        $sortSplat.Property = { $_.gci.CreationTime }
    } elseif ($orderUpdated) {
        $sortSplat.Property = {
            $old = Join-Path $_.gci.Fullname '*\install.json' | Get-ChildItem
            $new = Join-Path $_.gci.Fullname '*\scoop-install.json' | Get-ChildItem
            @($old, $new) | Get-ChildItem | Sort-Object -Property LastWriteTimeUtc | Select-Object -ExpandProperty LastWriteTimeUtc -Last 1
        }
    }

    $apps | Sort-Object @sortSplat | Where-Object { !$query -or ($_.name -match $query) } | ForEach-Object {
        $app = $_.name
        $global = $_.global
        $ver = Select-CurrentVersion -AppName $app -Global:$global

        $install_info = install_info $app $ver $global
        Write-Host "  $app " -NoNewline
        Write-Host -f DarkCyan $ver -NoNewline

        if ($global) { Write-Host -f DarkGreen ' *global*' -NoNewline }

        if (!$install_info) { Write-Host ' *failed*' -ForegroundColor DarkRed -NoNewline }
        if ($install_info.hold) { Write-Host ' *hold*' -ForegroundColor DarkMagenta -NoNewline }

        if ($install_info.bucket) {
            Write-Host -f Yellow " [$($install_info.bucket)]" -NoNewline
        } elseif ($install_info.url) {
            Write-Host -f Yellow " [$($install_info.url)]" -NoNewline
        }

        if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
            Write-Host -f DarkRed " {$($install_info.architecture)}" -NoNewline
        }
        Write-Host ''
    }
    Write-Host ''
    $exitCode = 0
} else {
    Write-Host "There aren't any apps installed."
    $exitCode = 1
}

exit $exitCode
