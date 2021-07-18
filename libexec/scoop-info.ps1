# Usage: scoop info [<OPTIONS>] <APP>
# Summary: Display information about an application.
#
# Options:
#   -h, --help                      Show help for this command.
#   -a, --arch <32bit|64bit|arm64>  Use the specified architecture, if the application's manifest supports it.

'buckets', 'core', 'depends', 'help', 'getopt', 'install', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Options, $Application, $_err = Resolve-GetOpt $args 'a:' 'arch='

if ($_err) { Stop-ScoopExecution -Message "scoop info: $_err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$Application = $Application[0]
$Architecture = Resolve-ArchitectureParameter -Architecture $Options.a, $Options.arch

# TODO: Adopt Resolve-ManifestInformation
if ($Application -match '^(ht|f)tps?://|\\\\') {
    # check if $Application is a URL or UNC path
    $url = $Application
    $Application = appname_from_url $url
    $Global = installed $Application $true
    $Status = app_status $Application $Global
    $Manifest = url_manifest $url
    $manifest_file = $url
} else {
    # else $Application is a normal app name
    $Global = installed $Application $true
    $Application, $bucket, $null = parse_app $Application
    $Status = app_status $Application $Global
    $Manifest, $bucket = find_manifest $Application $bucket
}

if (!$Manifest) { Stop-ScoopExecution -Message "Could not find manifest for '$(show_app $Application $bucket)'" }

$Name = $Application

$install = install_info $Name $Status.version $Global
$Status.installed = $install.bucket -eq $bucket
$version_output = $Manifest.version
if (!$manifest_file) {
    $manifest_file = manifest_path $Name $bucket
}

$currentVersion = Select-CurrentVersion -AppName $Name -Global:$Global
$dir = versiondir $Name $currentVersion $Global
$original_dir = versiondir $Name $Manifest.version $Global
$persist_dir = persistdir $Name $Global

if ($Status.installed) {
    $manifest_file = manifest_path $Name $install.bucket
    if ($install.url) {
        $manifest_file = $install.url
    }
    if ($Status.version -eq $Manifest.version) {
        $version_output = $Status.version
    } else {
        $version_output = "$($Status.version) (Update to $($Manifest.version) available)"
    }
    $Architecture = $install.architecture
}

$Message = @("Name: $Name")
$Message += "Version: $version_output"
if ($Manifest.description) { $Message += "Description: $($Manifest.description)" }
if ($Manifest.homepage) { $Message += "Website: $($Manifest.homepage)" }

# Show license
# TODO: Rework
if ($Manifest.license) {
    $license = $Manifest.license
    if ($Manifest.license.identifier -and $Manifest.license.url) {
        $license = "$($Manifest.license.identifier) ($($Manifest.license.url))"
    } elseif ($Manifest.license -match '^((ht)|f)tps?://') {
        $license = "$($Manifest.license)"
    } elseif ($Manifest.license -match '[|,]') {
        $licurl = $Manifest.license.Split('|,') | ForEach-Object { "https://spdx.org/licenses/$_.html" }
        $license = "$($Manifest.license) ($($licurl -join ', '))"
    } else {
        $license = "$($Manifest.license) (https://spdx.org/licenses/$($Manifest.license).html)"
    }
    $Message += "License: $license"
}
if ($Manifest.changelog) {
    $ch = $Manifest.changelog
    if (!$ch.StartsWith('http')) {
        if ($Status.installed) {
            $ch = Join-Path $dir $ch
        } else {
            $ch = "Could be found in file '$ch' inside application directory. Install application to see a recent changes"
        }
    }
    $Message += "Changelog: $ch"
}

# Manifest file
$Message += @('Manifest:', "  $manifest_file")

# Show installed versions
if ($Status.installed) {
    $Message += 'Installed:'
    $versions = Get-InstalledVersion -AppName $Name -Global:$Global
    $versions | ForEach-Object {
        $dir = versiondir $Name $_ $Global
        if ($Global) { $dir += ' *global*' }
        $Message += "  $dir"
    }
} else {
    $Message += 'Installed: No'
}

$binaries = @(arch_specific 'bin' $Manifest $Architecture)
if ($binaries) {
    $Message += 'Binaries:'
    $add = ''
    foreach ($b in $binaries) {
        $addition = "$b"
        if ($b -is [System.Array]) {
            $addition = $b[0]
            if ($b[1]) {
                $addition = "$($b[1]).exe"
            }
        }
        $add = "$add $addition"
    }
    $Message += $add
}

#region Environment
$env_set = arch_specific 'env_set' $Manifest $Architecture
$env_add_path = @(arch_specific 'env_add_path' $Manifest $Architecture)

if ($env_set -or $env_add_path) {
    $m = 'Environment:'
    if (!$Status.installed) { $m += ' (simulated)' }
    $Message += $m
}

if ($env_set) {
    foreach ($es in $env_set | Get-Member -MemberType 'NoteProperty') {
        $value = env $es.Name $Global
        if (!$value) {
            $value = format $env_set.$($es.Name) @{ 'dir' = $dir }
        }
        $Message += "  $($es.Name)=$value"
    }
}
if ($env_add_path) {
    # TODO: Should be path rather joined on one line or with multiple PATH=??
    # Original:
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\global\node_modules\.bin
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\Yarn\bin
    # vs:
    # PATH=%PATH%;C:\SCOOP\apps\yarn\current\global\node_modules\.bin;C:\SCOOP\apps\yarn\current\Yarn\bin
    foreach ($ea in $env_add_path | Where-Object { $_ }) {
        $to = "$dir"
        if ($ea -ne '.') {
            $to = "$to\$ea"
        }
        $Message += "  PATH=%PATH%;$to"
    }
}
#endregion Environment

# Available versions:
$vers = Find-BucketDirectory -Name $bucket | Join-Path -ChildPath "old\$Name" | Get-ChildItem -ErrorAction 'SilentlyContinue' -File |
    Where-Object -Property 'Name' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"

if ($vers.Count -gt 0) { $Message += "Available Versions: $($vers.BaseName -join ', ')" }

Write-UserMessage -Message $Message -Output

# Show notes
show_notes $Manifest $dir $original_dir $persist_dir

exit $ExitCode
