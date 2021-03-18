# Usage: scoop search [query] [options]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
#
# Options:
#   -h, --help      Show help for this command.
#   -r, --remote    Force remote search in known buckets using Github API.
#                       Remote search does not utilize advanced search methods (descriptions, binary, shortcuts, ... matching).
#                       It only uses manifest name to search.

'getopt', 'buckets', 'Helpers', 'Search' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $Query, $err = getopt $args 'r' 'remote'
if ($err) { Stop-ScoopExecution -Message "scoop search: $err" -ExitCode 2 }
$Remote = $opt.r -or $opt.remote
if ($Query) {
    try {
        $Query = New-Object System.Text.RegularExpressions.Regex $Query, 'IgnoreCase'
    } catch {
        Stop-ScoopExecution -Message "Invalid regular expression: $($_.Exception.InnerException.Message)"
    }
} else {
    $Query = $null
}

$exitCode = 0

Write-Host 'Searching in local buckets ...'
$localResults = @()

foreach ($bucket in (Get-LocalBucket)) {
    $result = Search-LocalBucket -Bucket $bucket -Query $Query
    if (!$result) { continue }

    $localResults += $result
    foreach ($res in $result) {
        Write-Host "$bucket" -ForegroundColor 'Yellow' -NoNewline
        Write-Host '/' -NoNewline
        Write-Host $res.name -ForegroundColor 'Green'
        Write-Host '  Version: ' -NoNewline
        Write-Host $res.version -ForegroundColor 'DarkCyan'

        $toPrint = @()
        if ($res.description) { $toPrint += "  Description: $($res.description)" }
        if ($res.matchingBinaries) {
            $toPrint += '  Binaries:'
            $res.matchingBinaries | ForEach-Object {
                $str = if ($_.exe -contains $_.name ) { $_.exe } else { "$($_.exe) > $($_.name)" }
                $toPrint += "    - $str"
            }
        }
        if ($res.matchingShortcuts) {
            $toPrint += '  Shortcuts:'
            $res.matchingShortcuts | ForEach-Object {
                $str = if ($_.exe -contains $_.name ) { $_.exe } else { "$($_.exe) > $($_.name)" }
                $toPrint += "    - $str"
            }
        }

        Write-UserMessage -Message $toPrint -Output:$false
    }
}

if (!$localResults) { Write-UserMessage -Message 'No matches in local buckets found' }
if (!$localResults -or $Remote) {
    if (!(Test-GithubApiRateLimitBreached)) {
        Write-Host 'Searching in remote buckets ...'
        $remoteResults = Search-AllRemote -Query $Query

        if ($remoteResults) {
            Write-Host "`nResults from other known buckets:`n"
            foreach ($r in $remoteResults) {
                Write-Host "'$($r.bucket)' bucket (Run 'scoop bucket add $($r.bucket)'):"
                $r.results | ForEach-Object { "    $_" }
            }
        } else {
            Stop-ScoopExecution 'No matches in remote buckets found'
        }
    } else {
        Stop-ScoopExecution "GitHub ratelimit reached: Cannot query known repositories, please try again later"
    }
}

exit $exitCode
