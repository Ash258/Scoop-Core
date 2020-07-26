# Usage: scoop install <app> [options]
# Summary: Install apps
# Help: e.g. The usual way to install an app (uses your local 'buckets'):
#   scoop install git
#   scoop install extras/googlechrome
#
# To install an app from a manifest at a URL:
#   scoop install https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/runat.json
#
# To install an app from a manifest on your computer
#   scoop install \path\to\app.json
#
# Options:
#   -g, --global              Install the app globally
#   -i, --independent         Don't install dependencies automatically
#   -k, --no-cache            Don't use the download cache
#   -s, --skip                Skip hash validation (use with caution!)
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it

'Helpers', 'core', 'manifest', 'buckets', 'decompress', 'install', 'shortcuts', 'psmodules', 'Update', 'Versions', 'help', 'getopt', 'depends' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

function is_installed($app, $global) {
    if ($app.EndsWith('.json')) {
        $app = [System.IO.Path]::GetFileNameWithoutExtension($app)
    }
    if (installed $app $global) {
        function gf($g) { if ($g) { ' --global' } }

        $version = Select-CurrentVersion -AppName $app -Global:$global
        if (!(install_info $app $version $global)) {
            Write-UserMessage -Err -Message @(
                "It looks like a previous installation of $app failed."
                "Run 'scoop uninstall $app$(gf $global)' before retrying the install."
            )
        }
        Write-UserMessage -Warning -Message @(
            "'$app' ($version) is already installed.",
            "Use 'scoop update $app$(gf $global)' to install a new version."
        )

        return $true
    }

    return $false
}

$opt, $apps, $err = getopt $args 'gfiksa:' 'global', 'force', 'independent', 'no-cache', 'skip', 'arch='
if ($err) { Stop-ScoopExecution -Message "scoop install: $err" -ExitCode 2 }

$exitCode = 0
$problems = 0
$global = $opt.g -or $opt.global
$check_hash = !($opt.s -or $opt.skip)
$independent = $opt.i -or $opt.independent
$use_cache = !($opt.k -or $opt.'no-cache')
$architecture = default_architecture

try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    Stop-ScoopExecution -Message "ERROR: $_" -ExitCode 2
}
if (!$apps) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }
if ($global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed apps' -ExitCode 4 }

if (is_scoop_outdated) { Update-Scoop }

if ($apps.length -eq 1) {
    $app, $null, $version = parse_app $apps
    if ($null -eq $version -and (is_installed $app $global)) {
        return
    }
}

# get any specific versions that need to handled first
$specific_versions = $apps | Where-Object {
    $null, $null, $version = parse_app $_
    return $null -ne $version
}

# compare object does not like nulls
if ($specific_versions.Length -gt 0) {
    $difference = Compare-Object -ReferenceObject $apps -DifferenceObject $specific_versions -PassThru
} else {
    $difference = $apps
}

$specific_versions_paths = @()
foreach ($sp in $specific_versions) {
    $app, $bucket, $version = parse_app $sp
    if (installed_manifest $app $version) {
        Write-UserMessage -Warn -Message @(
            "'$app' ($version) is already installed.",
            "Use 'scoop update $app$global_flag' to install a new version."
        )
        continue
    } else {
        try {
            $specific_versions_paths += generate_user_manifest $app $bucket $version
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Color DarkRed
            ++$problems
        }
    }
}
$apps = @(($specific_versions_paths + $difference) | Where-Object { $_ } | Sort-Object -Unique)

# remember which were explictly requested so that we can
# differentiate after dependencies are added
$explicit_apps = $apps

if (!$independent) {
    $apps = install_order $apps $architecture # adds dependencies
}
ensure_none_failed $apps $global

$apps, $skip = prune_installed $apps $global

$skip | Where-Object { $explicit_apps -contains $_ } | ForEach-Object {
    $app, $null, $null = parse_app $_
    $version = Select-CurrentVersion -AppName $app -Global:$global
    Write-UserMessage -Message "'$app' ($version) is already installed. Skipping." -Warning
}

$suggested = @{ }

foreach ($app in $apps) {
    try {
        install_app $app $architecture $global $suggested $use_cache $check_hash
    } catch {
        ++$problems
        Write-UserMessage -Message $_.Exception.Message -Err
        continue
    }
}

show_suggestions $suggested

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
