# Usage: scoop info <app> [options]
# Summary: Display information about an app
#
# Options:
#   -h, --help      Show help for this command.

param($app)

'buckets', 'core', 'depends', 'help', 'install', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

if (!$app) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }

if ($app -match '^(ht|f)tps?://|\\\\') {
    # check if $app is a URL or UNC path
    $url = $app
    $app = appname_from_url $url
    $global = installed $app $true
    $status = app_status $app $global
    $manifest = url_manifest $url
    $manifest_file = $url
} else {
    # else $app is a normal app name
    $global = installed $app $true
    $app, $bucket, $null = parse_app $app
    $status = app_status $app $global
    $manifest, $bucket = find_manifest $app $bucket
}

if (!$manifest) { Stop-ScoopExecution -Message "Could not find manifest for '$(show_app $app $bucket)'." }

$install = install_info $app $status.version $global
$status.installed = $install.bucket -eq $bucket
$version_output = $manifest.version
if (!$manifest_file) {
    $manifest_file = manifest_path $app $bucket
}

$currentVersion = Select-CurrentVersion -AppName $app -Global:$global
$dir = versiondir $app $currentVersion $global
$original_dir = versiondir $app $manifest.version $global
$persist_dir = persistdir $app $global

$architecture = default_architecture
if ($status.installed) {
    $manifest_file = manifest_path $app $install.bucket
    if ($install.url) {
        $manifest_file = $install.url
    }
    if ($status.version -eq $manifest.version) {
        $version_output = $status.version
    } else {
        $version_output = "$($status.version) (Update to $($manifest.version) available)"
    }
    $architecture = $install.architecture
}

$message = @("Name: $app")
$message += "Version: $version_output"
if ($manifest.description) { $message += "Description: $($manifest.description)" }
if ($manifest.homepage) { $message += "Website: $($manifest.homepage)" }

# Show license
# TODO: Rework
if ($manifest.license) {
    $license = $manifest.license
    if ($manifest.license.identifier -and $manifest.license.url) {
        $license = "$($manifest.license.identifier) ($($manifest.license.url))"
    } elseif ($manifest.license -match '^((ht)|f)tps?://') {
        $license = "$($manifest.license)"
    } elseif ($manifest.license -match '[|,]') {
        $licurl = $manifest.license.Split('|,') | ForEach-Object { "https://spdx.org/licenses/$_.html" }
        $license = "$($manifest.license) ($($licurl -join ', '))"
    } else {
        $license = "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)"
    }
    $message += "License: $license"
}
if ($manifest.changelog) {
    $ch = $manifest.changelog
    if (!$ch.StartsWith('http')) {
        if ($status.installed) {
            $ch = Join-Path $dir $ch
        } else {
            $ch = "Could be found in file '$ch' inside application directory. Install application to see a recent changes"
        }
    }
    $message += "Changelog: $ch"
}

# Manifest file
$message += @('Manifest:', "  $manifest_file")

# Show installed versions
if ($status.installed) {
    $message += 'Installed:'
    $versions = Get-InstalledVersion -AppName $app -Global:$global
    $versions | ForEach-Object {
        $dir = versiondir $app $_ $global
        if ($global) { $dir += ' *global*' }
        $message += "  $dir"
    }
} else {
    $message += 'Installed: No'
}

$binaries = @(arch_specific 'bin' $manifest $architecture)
if ($binaries) {
    $message += 'Binaries:'
    $add = ''
    $binaries | ForEach-Object {
        $addition = "$_"
        if ($_ -is [System.Array]) {
            $addition = $_[0]
            if ($_[1]) {
                $addition = "$($_[1]).exe"
            }
        }
        $add = "$add $addition"
    }
    $message += $add
}

$env_set = arch_specific 'env_set' $manifest $architecture
$env_add_path = @(arch_specific 'env_add_path' $manifest $architecture)

if ($env_set -or $env_add_path) {
    $m = 'Environment:'
    if (!$status.installed) {
        $m += ' (simulated)'
    }
    $message += $m
}

if ($env_set) {
    $env_set | Get-Member -MemberType 'NoteProperty' | ForEach-Object {
        $value = env $_.name $global
        if (!$value) {
            $value = format $env_set.$($_.name) @{ 'dir' = $dir }
        }
        $message += "  $($_.name)=$value"
    }
}
if ($env_add_path) {
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        $to = "$dir"
        if ($_ -ne '.') {
            $to = "  PATH=%PATH%;$to\$_"
        }
        $message += $to
    }
}

# Available versions:
$vers = Find-BucketDirectory -Name $bucket | Join-Path -ChildPath "old\$app" | Get-ChildItem -ErrorAction 'SilentlyContinue' -File |
    Where-Object -Property 'Name' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"

if ($vers.Count -gt 0) { $message += "Available Versions: $($vers.BaseName -join ', ')" }

Write-UserMessage -Message $message -Output

# Show notes
show_notes $manifest $dir $original_dir $persist_dir

exit 0
