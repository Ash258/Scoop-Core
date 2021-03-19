'core', 'buckets', 'Helpers', 'install', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$_breachedRateLimit = $false

function Test-GithubApiRateLimitBreached {
    <#
    .SYNOPSIS
        Test if GitHub's rate limit was breached.
    .OUTPUTS [System.Boolean]
        Status of github rate limit breach.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param([Switch] $Breach)

    if ($Breach) { $script:_breachedRateLimit = $true }

    if (!$script:_breachedRateLimit) {
        $githubRateLimit = (Invoke-RestMethod -Uri 'https://api.github.com/rate_limit').resources.core
        debug $githubRateLimit.remaining
        if ($githubRateLimit.remaining -eq 0) {
            $script:_breachedRateLimit = $true
            $limitResetOn = [System.Timezone]::CurrentTimeZone.ToLocalTime(([System.Datetime]'1/1/1970').AddSeconds($githubRateLimit.reset)).ToString()
            debug $limitResetOn
        }
    }

    return $script:_breachedRateLimit
}

function Search-RemoteBucket {
    <#
    .SYNOPSIS
        Search remote bucket using GitHub API.
    .PARAMETER Bucket
        Specifies the bucket name to be searched in.
    .PARAMETER Query
        Specifies the regular expression to be searched in remote.
    .OUTPUTS [System.String[]]
        Array of hashtable results of search
    #>
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param(
        [String] $Bucket,
        [AllowNull()]
        [String] $Query
    )

    process {
        $repo = known_bucket_repo $Bucket
        if (!$repo) { return $null }
        if (Test-GithubApiRateLimitBreached) {
            Write-UserMessage -Message "GitHub ratelimit reached: Cannot query $repo" -Err
            return $null
        }

        $result = $null

        $uri = [System.Uri]($repo)
        if ($uri.AbsolutePath -match '/([a-zA-Z\d]*)/([a-zA-Z\d-]*)(\.git|/)?') {
            $user = $Matches[1]
            $repoName = $Matches[2]
            $params = @{
                'Uri' = "https://api.github.com/repos/$user/$repoName/git/trees/HEAD?recursive=1"
                # 'Headers' = @{
                #     'Authorization' = 'token $ghToken'
                # }
            }
            if ((Get-Command 'Invoke-RestMethod').Parameters.ContainsKey('ResponseHeadersVariable')) { $params.Add('ResponseHeadersVariable', 'headers') }

            try {
                $response = Invoke-RestMethod @params
            } catch {
                Test-GithubApiRateLimitBreached -Breach | Out-Null
                return $null
            }

            if ($headers -and $headers['X-RateLimit-Remaining']) {
                $rateLimitRemaining = $headers['X-RateLimit-Remaining'][0]
                debug $rateLimitRemaining
                if ($rateLimitRemaining -eq 0) { Test-GithubApiRateLimitBreached -Breach | Out-Null }
            }
            $result = $response.tree | Where-Object -Property 'path' -Match "(^(?:bucket/)(.*$Query.*)\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$)" `
            | ForEach-Object { $Matches[2] }
        }

        return $result
    }
}

function Search-AllRemote {
    <#
    .SYNOPSIS
        Search all remote buckets using GitHub API.
    .DESCRIPTION
        Remote search happens only in buckets, which are not added locally and only manifest name is taken into account.
    .PARAMETER Query
        Specifies the regular expression to be searched in remote.
    .OUTPUTS [System.Object[]]
        Array of all result hashtables with bucket and results properties.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param([AllowNull()][String] $Query)

    process {
        $Query | Out-Null # PowerShell/PSScriptAnalyzer#1472
        $results = Get-KnownBucket | Where-Object { !(Find-BucketDirectory -Bucket $_ | Test-Path) } | ForEach-Object {
            @{
                'bucket'  = $_
                'results' = (Search-RemoteBucket -Bucket $_ -Query $Query)
            }
        } | Where-Object { $_.results }

        return @($results)
    }
}

function Search-LocalBucket {
    <#
    .SYNOPSIS
        Search all manifests in locally added bucket.
    .DESCRIPTION
        Descriptions, binaries and shortcuts will be used for searching.
    .PARAMETER Bucket
        Specifies the bucket name to be searched in.
    .PARAMETER Query
        Specifies the regular expression to be used for searching.
    .OUTPUTS [System.Object[]]
        Array of all result hashtables with bucket and results properties.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Bucket,
        [AllowNull()]
        [String] $Query
    )

    begin {
        $architecture = default_architecture
        $apps = @()
        $result = @()
    }

    process {
        foreach ($app in apps_in_bucket (Find-BucketDirectory -Name $Bucket)) {
            $manifest = manifest $app $Bucket
            $apps += @{
                'name'              = $app
                'version'           = $manifest.version
                'description'       = $manifest.description
                'bin'               = @(arch_specific 'bin' $manifest $architecture)
                'matchingBinaries'  = @()
                'shortcuts'         = @(arch_specific 'shortcuts' $manifest $architecture)
                'matchingShortcuts' = @()
            }
        }

        if (!$Query) { return $apps }

        foreach ($a in $apps) {
            # Manifest name matching
            if (($a.name -match $Query) -and ($result -notcontains $a)) { $result += $a }

            # Description matching
            if (($a.description -match $Query) -and ($result -notcontains $a)) { $result += $a }

            # Binary matching
            $a.bin | ForEach-Object {
                $executable, $shimName, $argument = shim_def $_
                if (($shimName -match $Query) -or ($executable -match $Query)) {
                    $bin = @{ 'exe' = $executable; 'name' = $shimName }
                    if ($result -contains $a) {
                        $result[$result.IndexOf($a)].matchingBinaries += $bin
                    } else {
                        $a.matchingBinaries += $bin
                        $result += $a
                    }
                }
            }

            # Shortcut matching
            foreach ($shortcut in $a.shortcuts) {
                # Is this necessary?
                if (($shortcut -is [System.Array]) -and ($shortcut.Length -ge 2)) {
                    $executable = $shortcut[0]
                    $name = $shortcut[1]

                    if (($name -match $Query) -or ($executable -match $Query)) {
                        $short = @{ 'exe' = $executable; 'name' = $name }
                        if ($result -contains $a) {
                            $result[$result.IndexOf($a)].matchingShortcuts += $short
                        } else {
                            $a.matchingShortcuts += $short
                            $result += $a
                        }
                    }
                }
            }
        }
    }

    end { return $result }
}
