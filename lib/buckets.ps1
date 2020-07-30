'core', 'Git' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

$SCOOP_BUCKETS_DIRECTORY = Join-Path $SCOOP_ROOT_DIRECTORY 'buckets'
$bucketsdir = $SCOOP_BUCKETS_DIRECTORY

function Find-BucketDirectory {
    <#
    .DESCRIPTION
        Return full path for bucket with given name.
        Main bucket will be returned as default.
    .PARAMETER Name
        Name of bucket.
    .PARAMETER Root
        Root folder of bucket repository will be returned instead of 'bucket' subdirectory (if exists).
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [String] $Name = 'main',
        [Switch] $Root
    )

    # Handle info passing empty string as bucket ($install.bucket)
    if (($null -eq $Name) -or ($Name -eq '')) { $Name = 'main' }

    $bucket = Join-Path $SCOOP_BUCKETS_DIRECTORY $Name
    $nested = Join-Path $bucket 'bucket'

    if (!$Root -and (Test-Path $nested)) { $bucket = $nested }

    return $bucket
}

function Get-LocalBucket {
    <#
    .SYNOPSIS
        List all local buckets.
    #>

    return (Get-ChildItem -Directory $SCOOP_BUCKETS_DIRECTORY).Name
}

function known_bucket_repos {
    $json = Join-Path $PSScriptRoot '..\buckets.json'

    return Get-Content $json -Raw | ConvertFrom-Json -ErrorAction Stop
}

function known_bucket_repo($name) {
    $buckets = known_bucket_repos

    return $buckets.$name
}

function Get-KnownBucket {
    <#
    .SYNOPSIS
        List names of all known buckets
    #>
    [CmdletBinding()]
    param()

    return known_bucket_repos | ForEach-Object { $_.PSObject.Properties | Select-Object -ExpandProperty 'Name' }
}

function apps_in_bucket($dir) {
    return Get-ChildItem $dir | Where-Object { $_.Name.EndsWith('.json') } | ForEach-Object { $_.Name -replace '.json$' }
}

function find_manifest($app, $bucket) {
    if ($bucket) {
        $manifest = manifest $app $bucket
        if ($manifest) { return $manifest, $bucket }
        return $null
    }

    foreach ($bucket in Get-LocalBucket) {
        $manifest = manifest $app $bucket
        if ($manifest) { return $manifest, $bucket }
    }
}

function Add-Bucket {
    <#
    .SYNOPSIS
        Add scoop bucket.
    .PARAMETER Name
        Specifies the name of bucket to be added.
    .PARAMETER RepositoryUrl
        Specifies the url of the git repository.
    #>
    param([Parameter(Mandatory)][String] $Name, [String] $RepositoryUrl)

    if (!$RepositoryUrl) {
        $RepositoryUrl = known_bucket_repo $Name
        if (!$RepositoryUrl) {
            throw "Specified bucket '$Name' is not known and cannot be added without providing URL."
        }
    }

    if (!(Test-CommandAvailable 'git')) {
        throw "Git is required for manipulating with buckets. Run 'scoop install git' and try again."
    }

    $bucketDirectory = Find-BucketDirectory -Name $Name -Root
    if (Test-Path $bucketDirectory) { throw "Bucket with name '$Name' already exists." }

    Write-UserMessage -Message 'Checking repository... ' -Output:$false
    $out = Invoke-GitCmd -Command 'ls-remote' -Argument """$RepositoryUrl""" -Proxy 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "'$RepositoryUrl' is not valid git repository ($out)"
    }

    ensure $SCOOP_BUCKETS_DIRECTORY | Out-Null
    $bucketDirectory = (ensure $bucketDirectory).Path
    Invoke-GitCmd -Command 'clone' -Argument '--quiet', """$RepositoryUrl""", """$bucketDirectory""" -Proxy

    Write-UserMessage -Message "The $name bucket was added successfully." -Success
}

function Remove-Bucket {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [String[]] $Name)

    process {
        foreach ($b in $Name) {
            $bucketDirectory = Find-BucketDirectory $b -Root

            if (!(Test-Path $bucketDirectory)) { throw "'$b' bucket not found" }

            Remove-Item $bucketDirectory -Force -Recurse
        }
    }
}

# TODO: Drop/Deprecate
function new_issue_msg($app, $bucket, $title, $body) {
    $app, $manifest, $bucket, $url = Find-Manifest $app $bucket
    $url = known_bucket_repo $bucket
    $bucket_path = Join-Path $SCOOP_BUCKETS_DIRECTORY $bucket

    if ((Test-path $bucket_path) -and (Join-Path $bucket_path '.git' | Test-Path -PathType Container)) {
        $remote = Invoke-GitCmd -Repository $bucket_path -Command 'config' -Argument '--get', 'remote.origin.url'
        # Support ssh and http syntax
        # git@PROVIDER:USER/REPO.git
        # https://PROVIDER/USER/REPO.git
        # https://regex101.com/r/OMEqfV
        if ($remote -match '(?:@|:\/\/)(?<provider>.+?)[:\/](?<user>.*)\/(?<repo>.+?)(?:\.git)?$') {
            $url = "https://$($Matches.Provider)/$($Matches.User)/$($Matches.Repo)"
        }
    }

    if (!$url) { return 'Please contact the bucket maintainer!' }

    $title = [System.Web.HttpUtility]::UrlEncode("$app@$($manifest.version): $title")
    $body = [System.Web.HttpUtility]::UrlEncode($body)
    $msg = "`nPlease try again"

    switch -Wildcard ($url) {
        '*github.*' {
            $url = $url -replace '\.git$'
            $url = "$url/issues/new?title=$title"
            if ($body) { $url += "&body=$body" }
            $msg = "$msg or create a new issue by using the following link and paste your console output:"
        }
        default {
            Write-UserMessage -Message 'Not supported platform' -Info
        }
    }

    return "$msg`n$url"
}

#region Deprecated
function bucketdir($name) {
    Show-DeprecatedWarning $MyInvocation 'Find-BucketDirectory'

    return Find-BucketDirectory $name
}

function buckets {
    Show-DeprecatedWarning $MyInvocation 'Get-LocalBucket'

    return Get-LocalBucket
}

function known_buckets {
    Show-DeprecatedWarning $MyInvocation 'Get-KnownBucket'

    return Get-KnownBucket
}

function rm_bucket($name) {
    Show-DeprecatedWarning $MyInvocation 'Remove-Bucket'

    Remove-Bucket -Name $name
}

function add_bucket($name, $repo) {
    Show-DeprecatedWarning $MyInvocation 'Add-Bucket'

    Add-Bucket -Name $name -RepositoryUrl $repo
}
#endregion Deprecated
