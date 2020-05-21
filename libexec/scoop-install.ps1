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

'core', 'manifest', 'buckets', 'decompress', 'install', 'shortcuts', 'psmodules', 'Update', 'Versions', 'help', 'getopt', 'depends' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

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
if ($err) { Write-UserMessage -Message "scoop install: $err" -Err; exit 2 }

$global = $opt.g -or $opt.global
$check_hash = !($opt.s -or $opt.skip)
$independent = $opt.i -or $opt.independent
$use_cache = !($opt.k -or $opt.'no-cache')
$architecture = default_architecture
try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_" 2
}

if (!$apps) { Write-UserMessage -Message '<app> missing' -Err; my_usage; exit 1 }

if ($global -and !(is_admin)) {
    abort 'ERROR: you need admin rights to install global apps' 4
}

if (is_scoop_outdated) {
    # TODO: do not call scoop externally
    Update-Scoop
}

if ($apps.length -eq 1) {
    $app, $null, $version = parse_app $apps
    if ($null -eq $version -and (is_installed $app $global)) {
        return
    }
}

# get any specific versions that we need to handle first
$specific_versions = $apps | Where-Object {
    $null, $null, $version = parse_app $_
    return $null -ne $version
}

# compare object does not like nulls
if ($specific_versions.length -gt 0) {
    $difference = Compare-Object -ReferenceObject $apps -DifferenceObject $specific_versions -PassThru
} else {
    $difference = $apps
}

$specific_versions_paths = $specific_versions | ForEach-Object {
    $app, $bucket, $version = parse_app $_
    if (installed_manifest $app $version) {
        abort "'$app' ($version) is already installed.`nUse 'scoop update $app$global_flag' to install a new version."
    }

    # TODO: Extract to function
    $bucketFolder = Find-BucketDirectory $bucket
    # TODO: YML
    $oldManifest = Join-Path $bucketFolder "old\$app\$version.json"
    if (Test-Path $oldManifest -PathType Leaf) {
        return $oldManifest
    } else {
        # Try to generate the manifest if older do not exists
        return generate_user_manifest $app $bucket $version
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

$suggested = @{ };

if (Test-Aria2Enabled) {
    Write-UserMessage -Warning -Message @(
        "Scoop uses 'aria2c' for multi-connection downloads."
        "Should it cause issues, run 'scoop config aria2-enabled false' to disable it."
    )
}

$exitCode = 0
foreach ($app in $apps) {
    try {
        # TODO: Resolve $appName as it is get from path
        # old/bat/0.14.0.json -> 0.14.0/current/install...
        install_app $app $architecture $global $suggested $use_cache $check_hash
    } catch {
        $exitCode = 3
        Write-UserMessage -Message $_.Exception.Message -Err
        continue
    }
}

show_suggestions $suggested

exit $exitCode
