# Usage: scoop export [options] > filename
# Summary: Exports (an importable) list of installed apps
#
# Options:
#   -h, --help      Show help for this command.

'core', 'Versions', 'manifest', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias
$def_arch = default_architecture

$local = installed_apps $false | ForEach-Object { @{ 'name' = $_; 'global' = $false } }
$global = installed_apps $true | ForEach-Object { @{ 'name' = $_; 'global' = $true } }

$apps = @($local) + @($global)

if ($apps) {
    $apps | Sort-Object -Property 'Name' | ForEach-Object {
        $app = $_.name
        $global = $_.global
        $ver = Select-CurrentVersion -AppName $app -Global:$global
        $global_display = $null; if ($global) { $global_display = ' *global*' }

        $install_info = install_info $app $ver $global
        $bucket = ''
        if ($install_info.bucket) {
            $bucket = ' [' + $install_info.bucket + ']'
        } elseif ($install_info.url) {
            $bucket = ' [' + $install_info.url + ']'
        }
        if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
            $arch = ' {' + $install_info.architecture + '}'
        } else {
            $arch = ''
        }

        # "$app (v:$ver) global:$($global.toString().tolower())"
        "$app (v:$ver)$global_display$bucket$arch"
    }
}

exit 0
