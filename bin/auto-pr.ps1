<#
.SYNOPSIS
    Updates manifests and pushes them or creates pull-requests.
.DESCRIPTION
    Updates manifests and pushes them directly to the master branch or creates pull-requests for upstream.
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
    [Parameter(Mandatory)]
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

'Helpers', 'manifest', 'json' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Upstream | Out-Null # PowerShell/PSScriptAnalyzer#1472
$Dir = Resolve-Path $Dir
$exitCode = 0
$problems = 0
$RepositoryRoot = Get-Item $Dir
if (($RepositoryRoot.BaseName -eq 'bucket') -and (!(Join-Path $RepositoryRoot '.git' | Test-Path -PathType 'Container'))) {
    $RepositoryRoot = $RepositoryRoot.Parent.FullName
} else {
    $RepositoryRoot = $RepositoryRoot.FullName
}
$repoContext = "-C ""$RepositoryRoot"""

if ($Help -or (!$Push -and !$Request)) {
    Write-UserMessage @'
Usage: auto-pr.ps1 [OPTION]

Mandatory options:
  -p,  -push                Push updates directly to 'origin master'
  -r,  -request             Create pull-requests on 'upstream master' for each update

Optional options:
  -u,  -upstream            Upstream repository with target branch
                            Only used if -r is set (default: lukesampson/scoop:master)
  -h,  -help
'@
    exit 3
}

if (!(Get-Command -Name 'hub' -CommandType 'Application' -ErrorAction 'SilentlyContinue')) {
    Stop-ScoopExecution -Message 'hub is required! Please refer to ''https://hub.github.com/'' to find out how to get hub for your platform.'
}

function execute($cmd) {
    Write-Host $cmd -ForegroundColor Green
    $output = Invoke-Expression $cmd

    if ($LASTEXITCODE -gt 0) { Stop-ScoopExecution -Message "^^^ Error! See above ^^^ (last command: $cmd)" }

    return $output
}

# json object, application name, upstream repository, relative path to manifest file
function pull_requests($json, [String] $app, [String] $upstream, [String] $manifestFile) {
    $version = $json.version
    $homepage = $json.homepage
    $branch = "manifest/$app-$version"

    execute "hub $repoContext checkout master"
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

Write-UserMessage 'Updating ...' -ForegroundColor 'DarkCyan'
if ($Push) {
    execute "hub $repoContext pull origin master"
    execute "hub $repoContext checkout master"
} else {
    execute "hub $repoContext pull upstream master"
    execute "hub $repoContext push origin master"
}

if (!$SkipCheckver) {
    & "$PSScriptRoot\checkver.ps1" -App $App -Dir $Dir -Update -SkipUpdated:$SkipUpdated
    if ($SpecialSnowflakes) {
        Write-UserMessage -Message "Forcing update on special snowflakes: $($SpecialSnowflakes -join ',')" -Color 'DarkCyan'
        $SpecialSnowflakes -split ',' | ForEach-Object {
            & "$PSScriptRoot\checkver.ps1" $_ -Dir $Dir -ForceUpdate
        }
    }
}

foreach ($changedFile in hub -C "$RepositoryRoot" diff --name-only | Where-Object { $_ -like 'bucket/*' }) {
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

        execute "hub $repoContext add $changedFile"
        # Detect if file was staged, because it's not when only LF or CRLF have changed
        $status = execute "hub $repoContext status --porcelain -uno"
        $status = $status | Where-Object { $_ -match "M\s{2}.*$($gci.Name)" }

        if ($status -and $status.StartsWith('M  ') -and $status.EndsWith($gci.Name)) {
            execute "hub $repoContext commit --message '${applicationName}: Update to version $version'"
        } else {
            Write-UserMessage "Skipping $applicationName because only LF/CRLF changes were detected ..." -Info
        }
    } else {
        pull_requests $manifestObject $applicationName $Upstream $changedFile
    }
}

if ($Push) {
    Write-UserMessage 'Pushing updates ...' -ForegroundColor 'DarkCyan'
    execute "hub $repoContext push origin master"
} else {
    Write-UserMessage 'Returning to master branch and removing unstaged files ...' -ForegroundColor 'DarkCyan'
    execute "hub $repoContext checkout --force master"
}

execute "hub $repoContext reset --hard"

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
