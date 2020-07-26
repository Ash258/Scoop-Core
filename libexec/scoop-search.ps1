# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.

param($query)

# TODO: Refactor
'core', 'buckets', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0

function bin_match($manifest, $query) {
    if (!$manifest.bin) { return $false }
    foreach ($bin in $manifest.bin) {
        $exe, $alias, $args = $bin
        $fname = Split-Path $exe -Leaf -ErrorAction Stop

        if ((strip_ext $fname) -match $query) { return $fname }
        if ($alias -match $query) { return $alias }
    }
    $false
}

function search_bucket($bucket, $query) {
    $apps = apps_in_bucket (Find-BucketDirectory $bucket) | ForEach-Object {
        @{ name = $_ }
    }

    if ($query) {
        $apps = $apps | Where-Object {
            if ($_.name -match $query) { return $true }
            $bin = bin_match (manifest $_.name $bucket) $query
            if ($bin) {
                $_.bin = $bin; return $true;
            }
        }
    }
    $apps | ForEach-Object { $_.version = (Get-LatestVersion -App $_.Name -Bucket $bucket); $_ }
}

function download_json($url) {
    $ProgressPreference = 'SilentlyContinue'
    $result = Invoke-WebRequest $url -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $ProgressPreference = 'Continue'
    return $result
}

function github_ratelimit_reached {
    return (download_json "https://api.github.com/rate_limit").Rate.Remaining -eq 0
}

function search_remote($bucket, $query) {
    $repo = known_bucket_repo $bucket

    $uri = [System.Uri]($repo)
    if ($uri.AbsolutePath -match '/([a-zA-Z0-9]*)/([a-zA-Z0-9-]*)(.git|/)?') {
        $user = $matches[1]
        $repo_name = $matches[2]
        $api_link = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        $result = download_json $api_link | Select-Object -ExpandProperty tree | Where-Object {
            $_.path -match "(^(.*$query.*).json$)"
        } | ForEach-Object { $matches[2] }
    }

    return $result
}

function search_remotes($query) {
    $buckets = known_bucket_repos
    $names = $buckets | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    $results = $names | Where-Object { !(Test-Path $(Find-BucketDirectory $_)) } | ForEach-Object {
        @{'bucket' = $_; 'results' = (search_remote $_ $query) }
    } | Where-Object { $_.results }

    if ($results.count -gt 0) {
        Write-UserMessage -Message @(
            'Results from other known buckets...'
            '(add them using ''scoop bucket add <name>'')'
            ''
        )
    }

    $results | ForEach-Object {
        "'$($_.bucket)' bucket:"
        $_.results | ForEach-Object { "    $_" }
        ""
    }
}

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
        ""
    }
}

if (!$local_results -and !(github_ratelimit_reached)) {
    $remote_results = search_remotes $query
    if (!$remote_results) { Stop-ScoopExecution -Message 'No matches found' -SkipSeverity }
    $remote_results
}

exit $exitCode
