# Usage: scoop cleanup [<OPTIONS>] <APP>...
# Summary: Perform cleanup on specified installed application(s) by removing old/not actively used versions.
# Help: All old/not used versions of application will be removed.
#
# You can use '*' in place of <APP> to cleanup all installed applications.
#
# Options:
#   -h, --help         Show help for this command.
#   -g, --global       Perform cleanup on globally installed application(s). (Include them if '*' is used)
#   -k, --cache        Remove outdated download cache. This will keep only the latest version cached.

'core', 'buckets', 'getopt', 'help', 'Helpers', 'install', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = getopt $args 'gk' 'global', 'cache'

if ($_err) { Stop-ScoopExecution -Message "scoop cleanup: $_err" -ExitCode 2 }

$Global = $Options.g -or $Options.global
$Cache = $Options.k -or $Options.cache
$Verbose = $true

if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }
if ($Global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to manipulate with globally installed applications' -ExitCode 4 }

if ($Applications -eq '*') {
    $Verbose = $false
    $Applications = applist (installed_apps $false) $false
    if ($Global) {
        $Applications += applist (installed_apps $true) $true
    }
} else {
    # TODO: Since this function does not indicate not installed applications it will lead to confusing messages
    # where there will be ERROR that application is not installed followed with Everything is shiny and 0 exit code
    $Applications = Confirm-InstallationStatus $Applications -Global:$Global
}

# $Applications is now a list of ($app, $global, $bucket?) tuples
foreach ($a in $Applications) {
    try {
        Clear-InstalledVersion -Application $a[0] -Global:($a[1]) -BeVerbose:$Verbose -Cache:$Cache
    } catch {
        Write-UserMessage -Message '', $_.Exception.Message -Err
        ++$Problems
        continue
    }
}

if ($Cache) { Join-Path $SCOOP_CACHE_DIRECTORY '*.download' | Remove-Item -ErrorAction 'Ignore' }

if ($Problems -gt 0) {
    $ExitCode = 10 + $Problems
} else {
    Write-UserMessage -Message 'Everything is shiny now!' -Success
}

exit $ExitCode
