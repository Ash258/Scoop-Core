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

'getopt', 'help', 'manifest', 'install', 'versions' | ForEach-Object {
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
function search_bucket($bucket, $Query) {
    $arch = default_architecture
    $apps = apps_in_bucket (Find-BucketDirectory $bucket) | ForEach-Object {
        $manifest = manifest $_ $bucket
        @{
            'name'              = $_
            'version'           = $manifest.version
            'description'       = $manifest.description
            'shortcuts'         = @(arch_specific 'shortcuts' $manifest $arch)
            'matchingShortcuts' = @()
            'bin'               = @(arch_specific 'bin' $manifest $arch)
            'matchingBinaries'  = @()
        }
    }

    if (!$Query) { return $apps }

    $result = @()

    foreach ($app in $apps) {
        if ($app.name -match $Query -and !$result.Contains($app)) {
            $result += $app
        }

        $app.bin | ForEach-Object {
            $exe, $name, $arg = shim_def $_
            if ($name -match $Query) {
                $bin = @{'exe' = $exe; 'name' = $name }
                if ($result.Contains($app)) {
                    $result[$result.IndexOf($app)].matchingBinaries += $bin
                } else {
                    $app.matchingBinaries += $bin
                    $result += $app
                }
            }
        }

        foreach ($shortcut in $app.shortcuts) {
            if ($shortcut -is [Array] -and $shortcut.length -ge 2) {
                $name = $shortcut[1]
                if ($name -match $Query) {
                    if ($result.Contains($app)) {
                        $result[$result.IndexOf($app)].matchingShortcuts += $name
                    } else {
                        $app.matchingShortcuts += $name
                        $result += $app
                    }
                }
            }
        }
    }

    return $result
}

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

    $uri = [System.uri]($repo)
    if ($uri.absolutepath -match '/([a-zA-Z\d]*)/([a-zA-Z\d-]*)(.git|/)?') {
        $user = $matches[1]
        $repo_name = $matches[2]
        $request_uri = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        try {
            if ((Get-Command Invoke-RestMethod).parameters.ContainsKey('ResponseHeadersVariable')) {
                $response = Invoke-RestMethod -Uri $request_uri -ResponseHeadersVariable headers
                if ($headers['X-RateLimit-Remaining']) {
                    $rateLimitRemaining = $headers['X-RateLimit-Remaining'][0]
                    debug $rateLimitRemaining
                    $ratelimit_reached = 1 -eq $rateLimitRemaining
                }
            } else {
                $response = Invoke-RestMethod -Uri $request_uri
                $ratelimit_reached = github_ratelimit_reached
            }

            $result = $response.tree | Where-Object -Property 'path' -Match "(^(.*$query.*)\.json$)" | ForEach-Object { $matches[2] }
        } catch [System.Web.Http.HttpResponseException] {
            $ratelimit_reached = $true
        }
    }

    return $result
}

function search_remotes($query) {
    $results = Get-KnownBucket | Where-Object { !(Find-BucketDirectory $_ | Test-Path) } | ForEach-Object {
        @{
            'bucket'  = $_
            'results' = (search_remote $_ $query)
        }
    } | Where-Object { $_.results }

    return $results
}
#endregion TODO: Export

Write-Host 'Searching in local buckets ...'
$local_results = @()

foreach ($bucket in (Get-LocalBucket)) {
    $result = search_bucket $bucket $Query
    if (!$result) { continue }

    $local_results += $result
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
            $res.matchingShortcuts | ForEach-Object { $toPrint += "    - $_" }
        }

        Write-UserMessage -Message $toPrint -Output:$false
    }
}

if (!$local_results) { Write-UserMessage -Message 'No matches in local buckets found' }
if (!$local_results -or $Remote) {
    if (!$ratelimit_reached) {
        Write-Host 'Searching in remote buckets ...'
        $remote_results = search_remotes $Query

        if ($remote_results) {
            Write-Host "`nResults from other known buckets:`n"
            $remote_results | ForEach-Object {
                Write-Host "'$($_.bucket)' bucket (Run 'scoop bucket add $($_.bucket)'):"
                $_.results | ForEach-Object { "    $_" }
            }
        } else {
            Stop-ScoopExecution 'No matches in remote buckets found'
        }
    } else {
        Stop-ScoopExecution "GitHub ratelimit reached: Cannot query known repositories, please try again later"
    }
}

exit $exitCode
