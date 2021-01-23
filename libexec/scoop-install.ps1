# Usage: scoop install <apps> [options]
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
#   -h, --help                Show help for this command.
#   -g, --global              Install the app globally.
#   -i, --independent         Don't install dependencies automatically.
#   -k, --no-cache            Don't use the download cache.
#   -s, --skip                Skip hash validation (use with caution!).
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it.

'Helpers', 'core', 'manifest', 'buckets', 'decompress', 'install', 'shortcuts', 'psmodules', 'Update', 'Versions', 'help', 'getopt', 'depends' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

function is_installed($app, $global, $version) {
    if ($app.EndsWith('.json')) {
        $app = [System.IO.Path]::GetFileNameWithoutExtension($app)
    }

    if (installed $app $global) {
        function gf($g) { if ($g) { ' --global' } }

        # Explicitly provided version indicate local workspace manifest with older version of already installed application
        if ($version) {
            $all = @(Get-InstalledVersion -AppName $app -Global:$global)
            return $all -contains $version
        }

        $version = Select-CurrentVersion -AppName $app -Global:$global
        if (!(install_info $app $version $global)) {
            Write-UserMessage -Err -Message @(
                "It looks like a previous installation of '$app' failed."
                "Run 'scoop uninstall $app$(gf $global)' before retrying the install."
            )
            return $true
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
    Stop-ScoopExecution -Message "$_" -ExitCode 2
}
if (!$apps) { Stop-ScoopExecution -Message 'Parameter <apps> missing' -Usage (my_usage) }
if ($global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed apps' -ExitCode 4 }

if (is_scoop_outdated) { Update-Scoop }

# Get any specific versions that need to be handled first
$specific_versions = $apps | Where-Object {
    $null, $null, $version = parse_app $_
    return $null -ne $version
}

# Compare object does not like nulls
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

# Remember which were explictly requested so that we can
# differentiate after dependencies are added
$explicit_apps = $apps

if (!$independent) {
    try {
        $apps = install_order $apps $architecture # Add dependencies
    } catch {
        $title, $body = $_.Exception.Message -split '\|-'
        Write-UserMessage -Message $body -Err
        if ($title -ne 'Ignore') {
            New-IssuePrompt -Application $app -Title $title -Body $body
        }
    }
}

# This should not be breaking error in case there are other apps specified
if ($apps.Count -eq 0) { Stop-ScoopExecution -Message 'Nothing to install' }

$apps = ensure_none_failed $apps $global

if ($apps.Count -eq 0) { Stop-ScoopExecution -Message 'Nothing to install' }

$apps, $skip = prune_installed $apps $global

$skip | Where-Object { $explicit_apps -contains $_ } | ForEach-Object {
    $app, $null, $null = parse_app $_
    $version = Select-CurrentVersion -AppName $app -Global:$global
    Write-UserMessage -Message "'$app' ($version) is already installed. Skipping." -Warning
}

$suggested = @{ }
$failedDependencies = @()

foreach ($app in $apps) {
    $bucket = $cleanApp = $null
    $applicationSpecificDependencies = @(deps $app $architecture)
    $cmp = Compare-Object $applicationSpecificDependencies $failedDependencies -ExcludeDifferent
    # Skip Installation because required depency failed
    if ($cmp -and ($cmp.InputObject.Count -gt 0)) {
        $f = $cmp.InputObject -join ', '
        Write-UserMessage -Message "'$app' cannot be installed due to failed dependency installation ($f)" -Err
        ++$problems
        continue
    }

    $cleanApp, $bucket = parse_app $app

    # Prevent checking of already installed applications if specific version was provided.
    # In this case app will be fullpath to the manifest in \workspace folder and specific version will contains <app>@<version>
    # Allow to install zstd@1.4.4 after 1.4.5 was installed before
    if ((Test-Path $app) -and ((Get-Item $app).Directory.FullName -eq (usermanifestsdir))) {
        $_v = (ConvertFrom-Manifest -Path $app).version
    } else {
        $_v = $null
    }

    if (is_installed $cleanApp $global $_v) { continue }

    # Install
    try {
        install_app $app $architecture $global $suggested $use_cache $check_hash
    } catch {
        ++$problems

        # Register failed dependencies
        if ($explicit_apps -notcontains $app) { $failedDependencies += $app }

        $title, $body = $_.Exception.Message -split '\|-'
        if (!$body) { $body = $title }
        Write-UserMessage -Message $body -Err
        debug $_.InvocationInfo
        if ($title -ne 'Ignore' -and ($title -ne $body)) { New-IssuePrompt -Application $cleanApp -Bucket $bucket -Title $title -Body $body }

        continue
    }
}

show_suggestions $suggested

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
