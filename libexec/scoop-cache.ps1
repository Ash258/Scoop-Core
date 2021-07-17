# Usage: scoop cache [<SUBCOMMAND>] [<OPTIONS>] [<APP>...]
# Summary: Show or clear the download cache.
# Help: Scoop caches downloaded files to remove the need for repeated downloads of same files.
#
# To see what is in the cache:
#   scoop cache show
# To remove downloads for a specific app:
#   scoop cache rm git
#
# To clear everything in cache, use:
#   scoop cache rm *
#
# Subcommands:
#   rm              Remove an application specific files from cache.
#   show            Show an overview of all cached files. Default subcommand when none is provided.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'Cache', 'getopt', 'help', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Problems = 0
$Options, $Cache, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop cache: $_err" -ExitCode 2 }

$Operation = $Cache[0]
$Applications = $Cache[1..($Cache.Count)]

if (!$Operation) { $Operation = 'show' }

switch ($Operation) {
    'show' {
        Show-CachedFileList -ApplicationFilter $Applications
    }
    'rm' {
        if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> is required for ''rm'' subcommand' -Usage (my_usage) }

        foreach ($app in $Applications) {
            try {
                Join-Path $SCOOP_CACHE_DIRECTORY "$app#*" | Remove-Item -ErrorAction 'Stop' -Force -Recurse
                Join-Path $SCOOP_CACHE_DIRECTORY "$app.txt" | Remove-Item -ErrorAction 'SilentlyContinue' -Force -Recurse
            } catch {
                Write-UserMessage -Message "Removing ${app}: $($_.Exception.Message)" -Err
                ++$Problems
            }
        }
    }
    default {
        Write-UserMessage -Message "Unknown subcommand: '$Operation'" -Err
        $ExitCode = 2
    }
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
