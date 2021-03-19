# Usage: scoop status [options]
# Summary: Show status and check for new app versions
#
# Options:
#   -h, --help      Show help for this command.

'core', 'Helpers', 'manifest', 'buckets', 'Versions', 'depends', 'Git' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

# check if scoop needs updating
$currentdir = versiondir 'scoop' 'current'
$needs_update = $false

if (Join-Path $currentdir '.git' | Test-Path -PathType 'Container') {
    $target = @{ 'Repository' = $currentdir }

    Invoke-GitCmd @target -Command 'fetch' -Argument '--quiet', 'origin' -Proxy
    $commits = Invoke-GitCmd @target -Command 'log' -Argument '--oneline', """HEAD..origin/$(get_config 'SCOOP_BRANCH' 'main')"""

    if ($commits) { $needs_update = $true }
} else {
    $needs_update = $true
}

if ($needs_update) {
    Write-UserMessage -Message "Scoop is out of date. Run 'scoop update' to get the latest changes." -Warning
} else {
    Write-UserMessage -Message 'Scoop is up to date.' -Success
}

$failed = @()
$outdated = @()
$removed = @()
$missing_deps = @()
$onhold = @()
$exitCode = 0

# local and global apps
foreach ($global in ($true, $false)) {
    $dir = appsdir $global
    if (!(Test-Path $dir)) { continue }

    foreach ($application in (Get-ChildItem $dir | Where-Object -Property 'Name' -NE -Value 'scoop')) {
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
    $exitCode = 3
    Write-UserMessage -Message 'Updates are available for:' -Color 'DarkCyan'
    $outdated.keys | ForEach-Object {
        $versions = $outdated.$_
        "    ${_}: $($versions[0]) -> $($versions[1])"
    }
}

if ($onhold) {
    Write-UserMessage -Message 'These apps are outdated and on hold:' -Color 'DarkCyan'
    $onhold.keys | ForEach-Object {
        $versions = $onhold.$_
        "    ${_}: $($versions[0]) -> $($versions[1])"
    }
}

if ($removed) {
    $exitCode = 3
    Write-UserMessage -Message 'These app manifests have been removed:' -Color 'DarkCyan'
    $removed.keys | ForEach-Object {
        "    $_"
    }
}

if ($failed) {
    $exitCode = 3
    Write-UserMessage 'These apps failed to install:' -Color 'DarkCyan'
    $failed.keys | ForEach-Object {
        "    $_"
    }
}

if ($missing_deps) {
    $exitCode = 3
    Write-UserMessage 'Missing runtime dependencies:' -Color 'DarkCyan'
    $missing_deps | ForEach-Object {
        $app, $deps = $_
        "    '$app' requires '$([String]::Join(', ', $deps))'"
    }
}

if (!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update) {
    Write-UserMessage -Message 'Everything is ok!' -Success
}

exit $exitCode
