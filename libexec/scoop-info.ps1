# Usage: scoop info [<OPTIONS>] <APP>
# Summary: Display information about an application.
# Help: When provided application is installed, all information will be shown based on the locally installed manifest.
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
# $Options, $Application, $_err = getopt $args 'a:gi' 'arch=', 'global', 'ignore-installed'
# TODO: Add some --remote parameter to not use installed manifest
#   -i, --ignore-installed >    Remote manifest will be used to get all required information. Ignoring locally installed manifest (scoop-manifest.json).
# TODO: Add --global
#   -g, --global                Show information about globally installed application.

if ($_err) { Stop-ScoopExecution -Message "scoop info: $_err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$Application = $Application[0]
$Architecture = Resolve-ArchitectureParameter -Architecture $Options.a, $Options.arch

$Resolved = $null
try {
    $Resolved = Resolve-ManifestInformation -ApplicationQuery $Application
} catch {
    Stop-ScoopExecution -Message $_.Exception.Message
}

# Variables
$Name = $Resolved.ApplicationName
$Message = @()
$Global = installed $Name $true # TODO: In case both of them are installed only global will be shown (--global parameter)
$Status = app_status $Name $Global
$Manifest = $Resolved.ManifestObject
$ManifestPath = @($Resolved.LocalPath)

# Application is installed. Could be from different url/bucket/
if ($Status.installed) {
    # Application is installed from different bucket
    if ($Resolved.Bucket -and ($Status.bucket -ne $Resolved.Bucket)) {
        $Status.installed = $false
        $Status.Add('reasonNotInstalled', 'BucketMismatch')
    }
    # Application is installed from different url
    if ($Status.installed -and $Resolved.Url -and ($Status.url -ne $Resolved.Url)) {
        $Status.installed = $false
        $Status.Add('reasonNotInstalled', 'UrlMismatch')
    }

    # Requested version is not installed
    if ($Status.installed -and ($Status.version -ne $Resolved.Version)) {
        $Status.installed = $false
        $Status.Add('reasonNotInstalled', 'VersionMismatch')
    }
}

$reason = $null
if ($Status.reasonNotInstalled) {
    $Manifest = $Resolved.ManifestObject

    switch ($Status.reasonNotInstalled) {
        'BucketMismatch' {
            $ManifestPath = $Resolved.LocalPath
            $reason = 'Application installed from different bucket'
        }
        'UrlMismatch' {
            $ManifestPath = $Resolved.Url
            $reason = 'Application installed from different URL'
        }
        'VersionMismatch' {
            try {
                $i = installed_manifest $Name $Manifest.version $Global
                if ($null -eq $i) {
                    throw 'trigger'
                }
                $Manifest = $i
                $ManifestPath = installed_manifest $Name $Manifest.version $Global -PathOnly
            } catch {
                $Status.reasonNotInstalled = 'VersionNotInstalled'
                $reason = 'Application installed with different version'
            }
        }
    }
} else {
    $ManifestPath = $Resolved.Url, (installed_manifest $Name $Manifest.version $Global -PathOnly), $Resolved.LocalPath | Where-Object {
        -not [String]::IsNullOrEmpty($_)
    }
}

$dir = (versiondir $Name $Manifest.version $Global).TrimEnd('\')
$original_dir = (versiondir $Name $Resolved.Version $Global).TrimEnd('\')
$persist_dir = (persistdir $Name $Global).TrimEnd('\')

# TODO: Show update possible

$Message = @("Name: $Name")
$Message += "Version: $($Manifest.Version)"
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
$Message += @('Manifest:')
foreach ($m in $ManifestPath) { $Message += "  $m" }

# Show installed versions
if ($Status.installed) {
    $Message += 'Installed:'
    $versions = Get-InstalledVersion -AppName $Name -Global:$Global
    $versions | ForEach-Object {
        $dir = versiondir $Name $_ $Global
        if ($Global) { $dir += ' *global*' }
        $Message += "  $dir"
    }

    $InstallInfo = install_info $Name $Manifest.version $Global
    $Architecture = $InstallInfo.architecture
} else {
    $inst = 'Installed: No'
    if ($reason) { $inst = "$inst ($reason)" }
    $Message += $inst
}

$binaries = @(arch_specific 'bin' $Manifest $Architecture)
if ($binaries) {
    $Message += 'Binaries:'
    $add = ' '
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
$vers = Find-BucketDirectory -Name $resolved.Bucket | Join-Path -ChildPath "old\$Name" | Get-ChildItem -ErrorAction 'SilentlyContinue' -File |
    Where-Object -Property 'Name' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"

if ($vers.Count -gt 0) { $Message += "Available Versions: $($vers.BaseName -join ', ')" }

Write-UserMessage -Message $Message -Output

# Show notes
show_notes $Manifest $dir $original_dir $persist_dir

exit $ExitCode
