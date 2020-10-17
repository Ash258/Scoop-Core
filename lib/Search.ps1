'core', 'buckets', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}
<#
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
    return (download_json 'https://api.github.com/rate_limit').Rate.Remaining -eq 0
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
#>

function Search-AllRemote {
    <#
    .SYNOPSIS
        Search all remote buckets using GitHub API.
    .DESCRIPTION
        Remote search utilize only manifest names and buckets which are not added locally.
    .PARAMETER Query
        Specifies the regular expression to be searched in remote.
    .OUTPUTS [System.Object[]]
        Array of all result hashtable with bucket and results properties.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param([String] $Query)

    process {
        $Query | Out-Null # PowerShell/PSScriptAnalyzer#1472
        $results = Get-KnownBucket | Where-Object { !(Find-BucketDirectory $_ | Test-Path) } | ForEach-Object {
            @{
                'bucket'  = $_
                'results' = (search_remote $_ $Query)
            }
        } | Where-Object { $_.results }

        return @($results)
    }
}
