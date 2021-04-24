# Usage: scoop cache [<SUBCOMMAND>] [<OPTIONS>] [<APP>...]
# Summary: Show or clear the download cache.
# Help: Scoop caches downloaded files to remove the need for repeated downloads of same files.
#
# You can use
#   scoop cache show
# to see what's in the cache, and
#   scoop cache rm git
# to remove downloads for a specific app.
#
# To clear everything in cache, use:
#   scoop cache rm *
#
# Subcommands:
#   rm              Remove an application specific files from cache.
#   show            Show an overview of all cached files. Default command when any is provided.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'Cache', 'getopt', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $arguments, $err = getopt $args
if ($err) { Stop-ScoopExecution -Message "scoop cache: $err" -ExitCode 2 }

$cmd = if ($arguments[0]) { $arguments[0] } else { 'show' }
$isShow = $cmd -eq 'show'
$applications = $arguments[1..($arguments.Count)]
$exitCode = 0
$problems = 0

if ($cmd -notin @('rm', 'show')) { Stop-ScoopExecution -Message "Unknown subcommand: '$cmd'" -Usage (my_usage) }
if (!$isShow -and !$applications) { Stop-ScoopExecution -Message 'Parameter <APP> is required for ''rm'' subcommand' -Usage (my_usage) }

if ($isShow) {
    Show-CachedFileList -ApplicationFilter $applications
} else {
    foreach ($app in $applications) {
        try {
            Join-Path $SCOOP_CACHE_DIRECTORY "$app#*" | Remove-Item -ErrorAction 'Stop' -Force -Recurse
            Join-Path $SCOOP_CACHE_DIRECTORY "$app.txt" | Remove-Item -ErrorAction 'SilentlyContinue' -Force -Recurse
        } catch {
            Write-UserMessage -Message "Removing ${app}: $($_.Exception.Message)" -Err
            ++$problems
        }
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
