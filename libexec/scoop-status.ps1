# Usage: scoop status
# Summary: Show status and check for new app versions

'core', 'manifest', 'buckets', 'Versions', 'depends', 'Git' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

# check if scoop needs updating
$currentdir = versiondir 'scoop' 'current'
$needs_update = $false

if (test-path "$currentdir\.git") {
    Push-Location $currentdir
    git_fetch -q origin
    # TODO: Fix me
    $commits = $(git log "HEAD..origin/$(scoop config SCOOP_BRANCH)" --oneline)
    if ($commits) { $needs_update = $true }
    Pop-Location
} else {
    $needs_update = $true
}

if ($needs_update) {
    Write-UserMessage -Message "Scoop is out of date. Run 'scoop update' to get the latest changes." -Warning
} else {
    Write-UserMessage -Message "Scoop is up to date." -Success
}

$failed = @()
$outdated = @()
$removed = @()
$missing_deps = @()
$onhold = @()
$exitCode = 0

foreach ($global in $true, $false) { # local and global apps
    $dir = appsdir $global
    if (!(test-path $dir)) { return }

    foreach ($application in Get-ChildItem $dir | Where-Object name -ne 'scoop'){
        $app = $application.name
        $status = app_status $app $global
        if ($status.failed) {
            $failed += @{ $app = $status.version }
        }
        if ($status.removed) {
            $removed += @{ $app = $status.version }
        }
        if ($status.outdated) {
            $outdated += @{ $app = @($status.version, $status.latest_version) }
            if ($status.hold) {
                $onhold += @{ $app = @($status.version, $status.latest_version) }
            }
        }
        if ($status.missing_deps) {
            $missing_deps += , (@($app) + @($status.missing_deps))
        }
    }
}

if ($outdated) {
    write-host -f DarkCyan 'Updates are available for:'
    $exitCode = 3
    $outdated.keys | ForEach-Object {
        $versions = $outdated.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if ($onhold) {
    write-host -f DarkCyan 'These apps are outdated and on hold:'
    $onhold.keys | ForEach-Object {
        $versions = $onhold.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if ($removed) {
    write-host -f DarkCyan 'These app manifests have been removed:'
    $exitCode = 3
    $removed.keys | ForEach-Object {
        "    $_"
    }
}

if ($failed) {
    write-host -f DarkCyan 'These apps failed to install:'
    $exitCode = 3
    $failed.keys | ForEach-Object {
        "    $_"
    }
}

if ($missing_deps) {
    $exitCode = 3
    write-host -f DarkCyan 'Missing runtime dependencies:'
    $missing_deps | ForEach-Object {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if (!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update) {
    Write-UserMessage -Message 'Everything is ok!' -Success
}

exit $exitCode
