# Usage: scoop install [<OPTIONS>] <APP>...
# Summary: Install specific application(s).
# Help: The usual way to install an application (uses your local 'buckets'):
#   scoop install git
#   scoop install extras/googlechrome
#
# To install an application from a manifest at a URL:
#   scoop install https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/runat.json
#
# To install an application from a manifest on your computer:
#   scoop install D:\path\to\app.json
#   scoop install ./install/pwsh.json
#
# Options:
#   -h, --help                      Show help for this command.
#   -a, --arch <32bit|64bit|arm64>  Use the specified architecture, if the application's manifest supports it.
#   -g, --global                    Install the application(s) globally.
#   -i, --independent               Do not install dependencies automatically.
#   -k, --no-cache                  Do not use the download cache.
#   -s, --skip                      Skip hash validation (use with caution!).

'core', 'buckets', 'decompress', 'depends', 'getopt', 'help', 'Helpers', 'manifest', 'shortcuts', 'psmodules', 'Update', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: Export
# TODO: Cleanup
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

$opt, $apps, $err = Resolve-GetOpt $args 'gfiksa:' 'global', 'force', 'independent', 'no-cache', 'skip', 'arch='
if ($err) { Stop-ScoopExecution -Message "scoop install: $err" -ExitCode 2 }

$exitCode = 0
$problems = 0
$global = $opt.g -or $opt.global
$check_hash = !($opt.s -or $opt.skip)
$independent = $opt.i -or $opt.independent
$use_cache = !($opt.k -or $opt.'no-cache')
$architecture = Resolve-ArchitectureParameter -Architecture $opt.a, $opt.arch

if (!$apps) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }
if ($global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed applications' -ExitCode 4 }

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
        New-IssuePromptFromException -ExceptionMessage $_.Exception.Message
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
$failedApplications = @()

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

    # TODO: Resolve-ManifestInformation
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
        if ($explicit_apps -notcontains $app) { $failedDependencies += $app } else { $failedApplications += $app }

        debug $_.InvocationInfo
        New-IssuePromptFromException -ExceptionMessage $_.Exception.Message -Application $cleanApp -Bucket $bucket

        continue
    }
}

show_suggestions $suggested

if ($failedApplications) {
    $pl = pluralize $failedApplications.Count 'This application' 'These applications'
    Write-UserMessage -Message "$pl failed to install: $($failedApplications -join ', ')" -Err
}

if ($failedDependencies) {
    $pl = pluralize $failedDependencies.Count 'This dependency' 'These dependencies'
    Write-UserMessage -Message "$pl failed to install: $($failedDependencies -join ', ')" -Err
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
