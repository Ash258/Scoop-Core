# Usage: scoop info [<OPTIONS>] <APP>
# Summary: Display information about an application.
#
# Options:
#   -h, --help                  Show help for this command.
#   -a, --arch <32bit|64bit>    Use the specified architecture, if the application's manifest supports it.

'buckets', 'core', 'depends', 'help', 'getopt', 'install', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Options, $Application, $_err = getopt $args 'a:' 'arch='

if ($_err) { Stop-ScoopExecution -Message "scoop info: $_err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$Application = $Application[0]
$Architecture = Resolve-ArchitectureParameter -Architecture $Options.a, $Options.arch

# TODO: Adopt Resolve-ManifestInformation
if ($Application -match '^(ht|f)tps?://|\\\\') {
    # check if $Application is a URL or UNC path
    $url = $Application
    $Application = appname_from_url $url
    $global = installed $Application $true
    $status = app_status $Application $global
    $manifest = url_manifest $url
    $manifest_file = $url
} else {
    # else $Application is a normal app name
    $global = installed $Application $true
    $Application, $bucket, $null = parse_app $Application
    $status = app_status $Application $global
    $manifest, $bucket = find_manifest $Application $bucket
}

if (!$manifest) { Stop-ScoopExecution -Message "Could not find manifest for '$(show_app $Application $bucket)'" }

$install = install_info $Application $status.version $global
$status.installed = $install.bucket -eq $bucket
$version_output = $manifest.version
if (!$manifest_file) {
    $manifest_file = manifest_path $Application $bucket
}

$currentVersion = Select-CurrentVersion -AppName $Application -Global:$global
$dir = versiondir $Application $currentVersion $global
$original_dir = versiondir $Application $manifest.version $global
$persist_dir = persistdir $Application $global

if ($status.installed) {
    $manifest_file = manifest_path $Application $install.bucket
    if ($install.url) {
        $manifest_file = $install.url
    }
    if ($status.version -eq $manifest.version) {
        $version_output = $status.version
    } else {
        $version_output = "$($status.version) (Update to $($manifest.version) available)"
    }
    $Architecture = $install.architecture
}

$message = @("Name: $Application")
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
    $versions = Get-InstalledVersion -AppName $Application -Global:$global
    $versions | ForEach-Object {
        $dir = versiondir $Application $_ $global
        if ($global) { $dir += ' *global*' }
        $message += "  $dir"
    }
} else {
    $message += 'Installed: No'
}

$binaries = @(arch_specific 'bin' $manifest $Architecture)
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

$env_set = arch_specific 'env_set' $manifest $Architecture
$env_add_path = @(arch_specific 'env_add_path' $manifest $Architecture)

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
    # TODO: Should be path rather joined on one line or with multiple PATH=??
    # Original:
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\global\node_modules\.bin
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\Yarn\bin
    # vs:
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\global\node_modules\.bin;C:\SCOOP\apps\yarn\current\Yarn\bin
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        $to = "$dir"
        if ($_ -ne '.') {
            $to = "$to\$_"
        }
        $message += "  PATH=%PATH%;$to"
    }
}

# Available versions:
$vers = Find-BucketDirectory -Name $bucket | Join-Path -ChildPath "old\$Application" | Get-ChildItem -ErrorAction 'SilentlyContinue' -File |
    Where-Object -Property 'Name' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"

if ($vers.Count -gt 0) { $message += "Available Versions: $($vers.BaseName -join ', ')" }

Write-UserMessage -Message $message -Output

# Show notes
show_notes $manifest $dir $original_dir $persist_dir

exit $ExitCode
