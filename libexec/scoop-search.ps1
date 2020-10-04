# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.

param($query)

'Helpers', 'Search' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0

try {
    $query = New-Object System.Text.RegularExpressions.Regex $query, 'IgnoreCase'
} catch {
    Stop-ScoopExecution -Message "Invalid regular expression: $($_.Exception.InnerException.Message)"
}

Get-LocalBucket | ForEach-Object {
    $res = search_bucket $_ $query
    $local_results = $local_results -or $res
    if ($res) {
        $name = "$_"

        Write-Host "'$name' bucket:"
        $res | ForEach-Object {
            $item = "    $($_.name) ($($_.version))"
            if ($_.bin) { $item += " --> includes '$($_.bin)'" }
            $item
        }
        ''
    }
}

if (!$local_results -and !(github_ratelimit_reached)) {
    $remote_results = search_remotes $query
    if (!$remote_results) { Stop-ScoopExecution -Message 'No matches found' -SkipSeverity }
    $remote_results
}

exit $exitCode
