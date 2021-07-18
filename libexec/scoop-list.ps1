# Usage: scoop list [<OPTIONS>] [<QUERY>]
# Summary: List installed applications.
# Help: Lists all installed applications, or the applications matching the specified query.
#
# Options:
#   -h, --help          Show help for this command.
#   -i, --installed     Applicaitons will be sorted by installed date.
#   -r, --reverse       Applications will be listed in descending order.
#                       In case of Installed or Updated, apps will be listed from newest to oldest.
#   -u, --updated       Applications will be sorted by update time.

'core', 'buckets', 'getopt', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Options, $Query, $_err = Resolve-GetOpt $args 'iur' 'installed', 'updated', 'reverse'

if ($_err) { Stop-ScoopExecution -Message "scoop list: $_err" -ExitCode 2 }

$OrderInstalled = $Options.i -or $Options.installed
$OrderUpdated = $Options.u -or $Options.updated
$Reverse = $Options.r -or $Options.reverse
$DefaultArchitecture = default_architecture

if ($OrderUpdated -and $OrderInstalled) { Stop-ScoopExecution -Message '--installed and --updated options cannot be used simultaneously' -ExitCode 2 }

$SortSplat = @{ 'Property' = { $_.name }; 'Descending' = $Reverse }
$Applications = @()
foreach ($gl in @($true, $false)) {
    $a = appsdir $gl

    if (!(Test-Path -LiteralPath $a)) { continue }

    foreach ($i in installed_apps $gl) {
        $Applications += @{
            'name'   = $i
            'gci'    = (Get-Item -LiteralPath "$a\$i")
            'global' = $gl
        }
    }
}

if (!$Applications) { Stop-ScoopExecution -Message 'No application installed' -ExitCode 0 -SkipSeverity }

if ($OrderInstalled) {
    $SortSplat.Property = { $_.gci.CreationTime }
} elseif ($OrderUpdated) {
    $SortSplat.Property = {
        $new = Join-Path $_.gci.FullName '*\scoop-install.json' | Get-ChildItem
        $new | Sort-Object -Property 'LastWriteTimeUtc' | Select-Object -ExpandProperty 'LastWriteTimeUtc' -Last 1
    }
}

$mes = if ($Query) { " matching '$Query'" }
Write-UserMessage -Message "Installed applications${mes}: `n"

$Applications | Sort-Object @SortSplat | Where-Object { !$Query -or ($_.name -match $Query) } | ForEach-Object {
    $app = $_.name
    $global = $_.global
    $ver = Select-CurrentVersion -AppName $app -Global:$global

    $installInfo = install_info $app $ver $global
    Write-Host "  $app " -NoNewline
    Write-Host $ver -ForegroundColor 'DarkCyan' -NoNewline

    if ($global) { Write-Host ' *global*' -ForegroundColor 'DarkGreen' -NoNewline }

    if (!$installInfo) { Write-Host ' *failed*' -ForegroundColor 'DarkRed' -NoNewline }
    if ($installInfo.hold) { Write-Host ' *hold*' -ForegroundColor 'DarkMagenta' -NoNewline }

    if ($installInfo.bucket) {
        Write-Host " [$($installInfo.bucket)]" -ForegroundColor 'Yellow' -NoNewline
    } elseif ($installInfo.url) {
        Write-Host " [$($installInfo.url)]" -ForegroundColor 'Yellow' -NoNewline
    }

    if ($installInfo.architecture -and ($DefaultArchitecture -ne $installInfo.architecture)) {
        Write-Host " {$($installInfo.architecture)}" -ForegroundColor 'DarkRed' -NoNewline
    }
    Write-Host ''
}
Write-Host ''

exit $ExitCode
