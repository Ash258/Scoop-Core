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

function Get-LocalBucket {
    <#
    .SYNOPSIS
        List all local buckets.
    #>

    return (Get-ChildItem -Directory $SCOOP_BUCKETS_DIRECTORY).Name
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

function add_bucket($name, $repo) {
    # TODO: Stop-ScoopExecution
    # TODO: Eliminate $usage_add
    if (!$name) { "<name> missing"; $usage_add; exit 1 }
    if (!$repo) {
        $repo = known_bucket_repo $name
        # TODO: Eliminate $usage_add
        if (!$repo) { "Unknown bucket '$name'. Try specifying <repo>."; $usage_add; exit 1 }
    }

    if (!(Test-CommandAvailable git)) {
        # TODO: Stop-ScoopExecution: throw
        abort "Git is required for buckets. Run 'scoop install git' and try again."
    }

    $dir = Find-BucketDirectory $name -Root
    if (Test-Path $dir) {
        # TODO: Stop-ScoopExecution: throw
        Write-UserMessage -Message "The '$name' bucket already exists. Use 'scoop bucket rm $name' to remove it." -Warning
        exit 0
    }

    Write-Host 'Checking repo... ' -NoNewline
    $out = Invoke-GitCmd -Command 'ls-remote' -Argument """$repo""" -Proxy 2>&1
    if ($lastexitcode -ne 0) {
        # TODO: Stop-ScoopExecution: throw
        abort "'$repo' doesn't look like a valid git repository`n`nError given:`n$out"
    }
    Write-Host 'ok'

    ensure $SCOOP_BUCKETS_DIRECTORY | Out-Null
    $dir = ensure $dir
    Invoke-GitCmd -Command 'clone' -Argument '--quiet', """$repo""", """$dir""" -Proxy

    Write-UserMessage -Message "The $name bucket was added successfully." -Success
}

function Remove-Bucket {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [String] $Name)

    $bucketDirectory = Find-BucketDirectory $Name -Root

    if (!(Test-Path $bucketDirectory)) { throw "'$Name' bucket not found" }

    Remove-Item $bucketDirectory -Force -Recurse
}

# TODO: Migrate to helpers
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
#endregion Deprecated
