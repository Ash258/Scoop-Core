# Usage: scoop status [<OPTIONS>]
# Summary: Show status and check for available updates for all installed applications.
# Help: Status command will check these factors and report if any of them is not satisfied:
#    Scoop installation is up-to-date.
#    Installed applications use the latest version.
#    Remote manifests of installed applications are available.
#    All applications are successfully installed.
#    All runtime dependencies are installed.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'buckets', 'depends', 'getopt', 'Git', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Failed = @()
$Outdated = @()
$Removed = @()
$MissingDependencies = @()
$Onhold = @()
$null, $null, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop status: $_err" -ExitCode 2 }

# Check if scoop needs updating
$ScoopInstallationDirectory = versiondir 'scoop' 'current'
$UpdateRequired = $false

if (Join-Path $ScoopInstallationDirectory '.git' | Test-Path -PathType 'Container') {
    $target = @{ 'Repository' = $ScoopInstallationDirectory }

    Invoke-GitCmd @target -Command 'fetch' -Argument '--quiet', 'origin' -Proxy
    $commits = Invoke-GitCmd @target -Command 'log' -Argument '--oneline', """HEAD..origin/$(get_config 'SCOOP_BRANCH' 'main')"""

    if ($commits) { $UpdateRequired = $true }
} else {
    $UpdateRequired = $true
}

if ($UpdateRequired) {
    Write-UserMessage -Message "Scoop is out of date. Run 'scoop update' to get the latest changes" -Warning
} else {
    Write-UserMessage -Message 'Scoop is up to date' -Success
}

# Local and global applications
foreach ($global in ($true, $false)) {
    $dir = appsdir $global
    if (!(Test-Path -LiteralPath $dir -PathType 'Container')) { continue }

    foreach ($application in (Get-ChildItem -LiteralPath $dir | Where-Object -Property 'Name' -NE -Value 'scoop')) {
        $app = $application.name
        $status = app_status $app $global

        if ($status.failed) { $Failed += @{ $app = $status.version } }
        if ($status.removed) { $Removed += @{ $app = $status.version } }
        if ($status.missing_deps) { $MissingDependencies += , (@($app) + @($status.missing_deps)) }
        if ($status.outdated) {
            $Outdated += @{ $app = @($status.version, $status.latest_version) }
            if ($status.hold) { $Onhold += @{ $app = @($status.version, $status.latest_version) } }
        }
    }
}

if ($Outdated) {
    $ExitCode = 3
    Write-UserMessage -Message 'Updates are available for:' -Color 'DarkCyan'
    $Outdated.Keys | ForEach-Object {
        Write-UserMessage -Message "    ${_}: $($Outdated.$_[0]) -> $($Outdated.$_[1])"
    }
}

if ($Onhold) {
    $ExitCode = 3
    Write-UserMessage -Message 'These applications are outdated and held:' -Color 'DarkCyan'
    $Onhold.Keys | ForEach-Object {
        Write-UserMessage -Message "    ${_}: $($Onhold.$_[0]) -> $($Onhold.$_[1])"
    }
}

if ($Removed) {
    $ExitCode = 3
    Write-UserMessage -Message 'These application manifests have been removed:' -Color 'DarkCyan'
    $Removed.Keys | ForEach-Object {
        Write-UserMessage -Message "    $_"
    }
}

if ($Failed) {
    $ExitCode = 3
    Write-UserMessage -Message 'These applications failed to install:' -Color 'DarkCyan'
    $Failed.Keys | ForEach-Object {
        Write-UserMessage -Message "    $_"
    }
}

if ($MissingDependencies) {
    $ExitCode = 3
    Write-UserMessage -Message 'Missing runtime dependencies:' -Color 'DarkCyan'
    $MissingDependencies | ForEach-Object {
        $app, $deps = $_
        Write-UserMessage -Message "    '$app' requires '$($deps -join ', ')'"
    }
}

if (!$UpdateRequired -and !$Removed -and !$Failed -and !$MissingDependencies -and !$Outdated) { Write-UserMessage -Message 'Everything is ok!' -Success }

exit $ExitCode
