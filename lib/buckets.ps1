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
        Specifies the name of the bucket.
    .PARAMETER Root
        Specifies to return root folder of bucket repository instead of 'bucket' subdirectory (if exists).
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Alias('Bucket')]
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
        List all local bucket names.
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
    $files = Get-ChildItem $dir -File
    $allowed = $files | Where-Object -Property 'Extension' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"

    return $allowed.BaseName
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

    Write-UserMessage -Message 'Checking repository...' -Output:$false
    $out = Invoke-GitCmd -Command 'ls-remote' -Argument """$RepositoryUrl""" -Proxy 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "'$RepositoryUrl' is not valid git repository ($out)"
    }

    ensure $SCOOP_BUCKETS_DIRECTORY | Out-Null
    $bucketDirectory = (ensure $bucketDirectory).Path
    Write-UserMessage -Message 'Cloning bucket repository...' -Output:$false
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

            try {
                Remove-Item $bucketDirectory -Force -Recurse -ErrorAction Stop
            } catch {
                throw "Bucket '$b' cannot be removed: $($_.Exception.Message)"
            }
            Write-UserMessage -Message "'$b' bucket removed" -Success
        }
    }
}

#region Deprecated
function bucketdir($name) {
    Show-DeprecatedWarning $MyInvocation 'Find-BucketDirectory'

    return Find-BucketDirectory $name
}
#endregion Deprecated
