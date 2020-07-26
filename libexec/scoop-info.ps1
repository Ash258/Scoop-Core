# Usage: scoop info <app>
# Summary: Display information about an app

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

$dir = versiondir $app 'current' $global
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

Write-Output "Name: $app"
if ($manifest.description) { Write-Output "Description: $($manifest.description)" }
Write-Output "Version: $version_output"
Write-Output "Website: $($manifest.homepage)"

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
    Write-Output "License: $license"
}

# Manifest file
Write-Output "Manifest:`n  $manifest_file"

if ($status.installed) {
    # Show installed versions
    Write-Output "Installed:"
    $versions = Get-InstalledVersion -AppName $app -Global:$global
    $versions | ForEach-Object {
        $dir = versiondir $app $_ $global
        if ($global) { $dir += " *global*" }
        Write-Output "  $dir"
    }
} else {
    Write-Output "Installed: No"
}

$binaries = @(arch_specific 'bin' $manifest $architecture)
if ($binaries) {
    $binary_output = "Binaries:`n "
    $binaries | ForEach-Object {
        if ($_ -is [System.Array]) {
            $binary_output += " $($_[1]).exe"
        } else {
            $binary_output += " $_"
        }
    }
    Write-Output $binary_output
}

$env_set = arch_specific 'env_set' $manifest $architecture
$env_add_path = @(arch_specific 'env_add_path' $manifest $architecture)

if ($env_set -or $env_add_path) {
    if ($status.installed) {
        Write-Output "Environment:"
    } else {
        Write-Output "Environment: (simulated)"
    }
}

if ($env_set) {
    $env_set | Get-Member -MemberType NoteProperty | ForEach-Object {
        $value = env $_.name $global
        if (!$value) {
            $value = format $env_set.$($_.name) @{ 'dir' = $dir }
        }
        Write-Output "  $($_.name)=$value"
    }
}
if ($env_add_path) {
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        if ($_ -eq '.') {
            Write-Output "  PATH=%PATH%;$dir"
        } else {
            Write-Output "  PATH=%PATH%;$dir\$_"
        }
    }
}

# Show notes
show_notes $manifest $dir $original_dir $persist_dir

exit 0
