<#
.SYNOPSIS
    Updates manifests and pushes them or creates pull-requests.
.DESCRIPTION
    Updates manifests and pushes them directly to the master (main) branch or creates pull-requests for upstream.
.PARAMETER Upstream
    Specifies the upstream repository with the target branch.
    Must be in format '<user>/<repo>:<branch>'
.PARAMETER App
    Specifies the manifest name to search.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
.PARAMETER Push
    Specifies to push updates directly to 'origin master'.
.PARAMETER Request
    Specifies to create pull-requests on 'upstream master' for each update instead of direct pushing.
.PARAMETER Help
    Specifies to print help to console.
.PARAMETER SpecialSnowflakes
    Specifies an array of manifest names, which should be updated all the time. (-ForceUpdate parameter to checkver)
.PARAMETER SkipUpdated
    Specifies to not show up-to-date manifests.
.PARAMETER SkipCheckver
    Specifies to skip checkver execution.
.EXAMPLE
    PS BUCKETROOT > .\bin\auto-pr.ps1 'someUsername/repository:branch' -Request
.EXAMPLE
    PS BUCKETROOT > .\bin\auto-pr.ps1 -Push
    Update all manifests inside 'bucket/' directory.
#>
param(
    [ValidateScript( {
            if ($_ -notmatch '^(.*)\/(.*):(.*)$') { throw 'Upstream must be in format: <user>/<repo>:<branch>' }
            $true
        })]
    [String] $Upstream,
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir,
    [Switch] $Push,
    [Switch] $Request,
    [Switch] $Help,
    [String[]] $SpecialSnowflakes,
    [Switch] $SkipUpdated,
    [Switch] $SkipCheckver
)

$checkverPath = Join-Path $PSScriptRoot 'checkver.ps1'
'Helpers', 'manifest', 'Git', 'json' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

if ($Help -or (!$Push -and !$Request) -or ($Request -and !$Upstream)) {
    Write-UserMessage @'
Usage: auto-pr.ps1 [OPTION]

Mandatory options:
  -p,  -Push                Push updates directly to 'origin master'
  -r,  -Request             Create pull-requests on 'upstream master' for each update

Optional options:
  -u,  -Upstream            Upstream repository with target branch.
                            If -Request is specified these parameter is required and will be used.
  -h,  -Help
'@
    exit 3
}

if ($Request -and !(Get-Command -Name 'hub' -CommandType 'Application' -ErrorAction 'SilentlyContinue')) {
    Stop-ScoopExecution -Message 'hub is required! Please refer to ''https://hub.github.com/'' to find out how to get hub for your platform.'
}

function _gitWrapper {
    param([String] $Command, [String[]] $Argument, [String] $Repository, [Switch] $GH, [Switch] $Proxy)

    process {
        $utility = if ($GH) { 'gh' } else { 'git' }
        $mes = "$utility -C ""$Repository"" $Command $($Argument -join ' ')"
        Write-UserMessage -Message $mes -Color 'Green'

        $output = Invoke-GitCmd -Repository $Repository -Command $Command -Argument $Argument -Proxy:$Proxy
        if ($LASTEXITCODE -gt 0) {
            Stop-ScoopExecution -Message "^^^ See above ^^^ (last command: $mes)"
        }

        return $output
    }
}

function _selectMasterBranch {
    $branches = _gitWrapper @splat -Command 'branch' -Argument '--all'
    $master = if ($branches -like '* remotes/origin/main') { 'main' } else { 'master' }

    return $master
}

# json object, application name, upstream repository, relative path to manifest file
function pull_requests($json, [String] $app, [String] $upstream, [String] $manifestFile) {
    $version = $json.version
    $homepage = $json.homepage
    $branch = "manifest/$app-$version"

    $master = _selectMasterBranch
    execute "hub $repoContext checkout $master"
    Write-UserMessage "hub rev-parse --verify $branch" -ForegroundColor 'Green'
    hub -C "$RepositoryRoot" rev-parse --verify $branch

    if ($LASTEXITCODE -eq 0) {
        Write-UserMessage "Skipping update $app ($version) ..." -ForegroundColor 'Yellow'
        ++$problems
        return
    }

    Write-UserMessage "Creating update $app ($version) ..." -ForegroundColor 'DarkCyan'
    execute "hub $repoContext checkout -b $branch"
    execute "hub $repoContext add $manifestFile"
    execute "hub $repoContext commit -m '${app}: Update to version $version'"
    Write-UserMessage "Pushing update $app ($version) ..." -ForegroundColor 'DarkCyan'
    execute "hub $repoContext push origin $branch"

    if ($LASTEXITCODE -gt 0) {
        Write-UserMessage -Message "Push failed! (hub push origin $branch)" -Err
        execute "hub $repoContext reset"
        ++$problems
        return
    }

    Start-Sleep -Seconds 1
    Write-UserMessage "Pull-Request update $app ($version) ..." -ForegroundColor 'DarkCyan'
    Write-UserMessage "hub pull-request -m '<msg>' -b '$upstream' -h '$branch'" -ForegroundColor 'Green'

    $msg = @"
${app}: Update to version $version

Hello lovely humans,
a new version of [$app]($homepage) is available.

| State       | Update :rocket: |
| :---------- | :-------------- |
| New version | $version        |
"@

    hub -C "$RepositoryRoot" pull-request -m "$msg" -b '$upstream' -h '$branch'
    if ($LASTEXITCODE -gt 0) {
        execute "hub $repoContext reset"
        Stop-ScoopExecution -Message "Pull Request failed! (hub pull-request -m '${app}: Update to version $version' -b '$upstream' -h '$branch')"
    }
}

$exitCode = 0
$problems = 0
$Dir = Resolve-Path $Dir
$RepositoryRoot = Get-Item $Dir

# Prevent edge case when someone name the bucket 'bucket'
if (($RepositoryRoot.BaseName -eq 'bucket') -and (!(Join-Path $RepositoryRoot '.git' | Test-Path -PathType 'Container'))) {
    $RepositoryRoot = $RepositoryRoot.Parent.FullName
} else {
    $RepositoryRoot = $RepositoryRoot.FullName
}

$RepositoryRoot = $RepositoryRoot.TrimEnd('/').TrimEnd('\') # Just in case
$repoContext = "-C ""$RepositoryRoot"""
$splat = @{ 'Repository' = $RepositoryRoot }

Write-UserMessage 'Updating ...' -ForegroundColor 'DarkCyan'
$master = _selectMasterBranch
if ($Push) {
    _gitWrapper @splat -Command 'pull' -Argument 'origin', $master -Proxy
    _gitWrapper @splat -Command 'checkout' -Argument $master
} else {
    _gitWrapper @splat -Command 'pull' -Argument 'upstream', $master -Proxy
    _gitWrapper @splat -Command 'push' -Argument 'origin', $master -Proxy
}

if (!$SkipCheckver) {
    & $checkverPath -App $App -Dir $Dir -Update -SkipUpdated:$SkipUpdated
    if ($SpecialSnowflakes) {
        Write-UserMessage -Message "Forcing update on special snowflakes: $($SpecialSnowflakes -join ',')" -Color 'DarkCyan'
        $SpecialSnowflakes -split ',' | ForEach-Object {
            & $checkverPath $_ -Dir $Dir -ForceUpdate
        }
    }
}

# Iterate only in bucket/* and ignore bucket/old/*
$manifestsToUpdate = _gitWrapper @splat -Command 'diff' -Argument '--name-only'
$manifestsToUpdate = $manifestsToUpdate | Where-Object { $_ -like 'bucket/*' }
$manifestsToUpdate = $manifestsToUpdate | Where-Object { $_ -notlike 'bucket/old/*' }

foreach ($changedFile in $manifestsToUpdate) {
    $gci = Get-Item "$RepositoryRoot\$changedFile"
    $applicationName = $gci.BaseName
    if ($gci.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $changedFile" -Info
        continue
    }

    try {
        $manifestObject = ConvertFrom-Manifest -Path $gci.FullName
    } catch {
        Write-UserMessage "Invalid manifest: $changedFile" -Err
        ++$problems
        continue
    }
    $version = $manifestObject.version

    if (!$version) {
        Write-UserMessage -Message "Invalid manifest: $changedFile ..." -Err
        ++$problems
        continue
    }

    if ($Push) {
        Write-UserMessage "Creating update $applicationName ($version) ..." -ForegroundColor 'DarkCyan'

        _gitWrapper @splat -Command 'add' -Argument """$changedFile"""

        # Archiving
        $archived = $false
        if ($manifestObject.autoupdate.archive -and ($manifestObject.autoupdate.archive -eq $true)) {
            $oldAppPath = Join-Path $Dir "old\$applicationName"
            $oldVersionManifest = @(_gitWrapper @splat -Command 'ls-files' -Argument '--other', '--exclude-standard') | Where-Object { $_ -like "bucket/old/$applicationName/*" }

            if ($oldVersionManifest) {
                _gitWrapper @splat -Command 'add' -Argument """$oldVersionManifest"""
                $oldVersion = (Join-Path $RepositoryRoot $oldVersionManifest | Get-Item).BaseName
                $archived = $true
            }
        }

        # Detect if file was staged, because it's not when only LF or CRLF have changed
        $status = _gitWrapper @splat -Command 'status' -Argument '--porcelain', '--untracked-files=no'
        $status = $status | Where-Object { $_ -match "M\s{2}.*$($gci.Name)" }
        if ($status -and $status.StartsWith('M  ') -and $status.EndsWith($gci.Name)) {
            $delim = if (Test-IsUnix) { '""' } else { '"' }
            $commitA = '--message', "$delim${applicationName}: Update to version $version$delim"
            if ($archived) {
                $commitA += '--message', "${delim}Archive version $oldVersion$delim"
            }
            _gitWrapper @splat -Command 'commit' -Argument $commitA
        } else {
            Write-UserMessage "Skipping $applicationName because only LF/CRLF changes were detected ..." -Info
        }
    } else {
        pull_requests $manifestObject $applicationName $Upstream $changedFile
    }
}

if ($Push) {
    Write-UserMessage 'Pushing updates ...' -ForegroundColor 'DarkCyan'
    _gitWrapper @splat -Command 'push' -Argument 'origin', $master -Proxy
} else {
    Write-UserMessage "Returning to $master branch and removing unstaged files ..." -ForegroundColor 'DarkCyan'
    _gitWrapper @splat -Command 'checkout' -Argument '--force', $master -Proxy
}

_gitWrapper @splat -Command 'reset' -Argument '--hard'

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
