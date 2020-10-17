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

'getopt', 'help', 'manifest', 'install', 'versions', 'Search' | ForEach-Object {
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
}

$exitCode = 0

#region TODO: Export
function github_ratelimit_reached {
    $githubRateLimitRemaining = (Invoke-RestMethod -Uri 'https://api.github.com/rate_limit').rate.remaining
    debug $githubRateLimitRemaining

    return $githubRateLimitRemaining -eq 0
}

$ratelimit_reached = github_ratelimit_reached

function search_remote($bucket, $query) {
    $repo = known_bucket_repo $bucket
    if ($ratelimit_reached) {
        Write-UserMessage -Message "GitHub ratelimit reached: Cannot query $repo" -Err
        return $null
    }

    $result = $null
    $uri = [System.uri]($repo)
    if ($uri.AbsolutePath -match '/([a-zA-Z\d]*)/([a-zA-Z\d-]*)(\.git|/)?') {
        $user = $matches[1]
        $repoName = $matches[2]
        $apiRequestUri = "https://api.github.com/repos/$user/$repoName/git/trees/HEAD?recursive=1"
        try {
            if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('ResponseHeadersVariable')) {
                $response = Invoke-RestMethod -Uri $apiRequestUri -ResponseHeadersVariable 'headers'
                if ($headers['X-RateLimit-Remaining']) {
                    $rateLimitRemaining = $headers['X-RateLimit-Remaining'][0]
                    debug $rateLimitRemaining
                    $ratelimit_reached = 1 -eq $rateLimitRemaining
                }
            } else {
                $response = Invoke-RestMethod -Uri $apiRequestUri
                $ratelimit_reached = github_ratelimit_reached
            }

            $result = $response.tree | Where-Object -Property 'path' -Match "(^(?:bucket/)?(.*$query.*)\.json$)" | ForEach-Object { $Matches[2] }
        } catch [System.Net.Http.HttpRequestException] {
            $ratelimit_reached = $true
        }
    }

    return $result
}
#endregion TODO: Export

Write-Host 'Searching in local buckets ...'
$localResults = @()

foreach ($bucket in (Get-LocalBucket)) {
    $result = Search-LocalBucket -Bucket $bucket -Query $Query
    if (!$result) { continue }

    $localResults += $result
    foreach ($res in $result) {
        Write-Host "$bucket" -NoNewline -ForegroundColor Yellow
        Write-Host '/' -NoNewline
        Write-Host $res.name -ForegroundColor Green
        Write-Host '  Version: ' -NoNewline
        Write-Host $res.version -ForegroundColor DarkCyan

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
    if (!$ratelimit_reached) {
        Write-Host 'Searching in remote buckets ...'
        $remoteResults = Search-AllRemote $Query

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
