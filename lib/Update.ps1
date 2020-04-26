'core', 'git', 'buckets' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

$DEFAULT_UPDATE_REPO = 'https://github.com/lukesampson/scoop'
$DEFAULT_UPDATE_BRANCH = 'master'
# TODO: CONFIG adopt refactor
$SHOW_UPDATE_LOG = get_config 'show_update_log' $true

function Update-ScoopCoreClone {
    <#
    .SYNOPSIS
        Temporary clone scoop into $env:SCOOP\apps\scoop\new and then move it to current.
    .PARAMETER Repo
        Specifies the git repository to be cloned.
    .PARAMETER Branch
        Specifies the git branch to be cloned.
    .PARAMETER TargetDirectory
        Specifies the final directory of scoop installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Repo,
        [Parameter(Mandatory)]
        [String] $Branch,
        [Parameter(Mandatory)]
        [String] $TargetDirectory
    )

    Write-UserMessage -Message "Cloning scoop installation from $Repo ($Branch)" -Info

    # TODO: Get rid of fullpath
    $newDir = fullpath (versiondir 'scoop' 'new')

    git_clone -q --single-branch --branch $Branch $Repo "`"$newDir`""

    # TODO: Stop-ScoopExecution
    # Check if scoop was successful downloaded
    if (!(Test-Path $newDir -PathType Container)) { abort 'Scoop update failed.' }

    # Replace non-git scoop with the git version
    Remove-Item $TargetDirectory -ErrorAction Stop -Force -Recurse
    Rename-Item $newDir $TargetDirectory
}

function Update-ScoopCorePull {
    <#
    .SYNOPSIS
        Update working scoop core installation using git pull.
    .PARAMETER TargetDirectory
        Specifies the final directory of scoop installation.
    .PARAMETER Repo
        Specifies the git repository to be cloned.
    .PARAMETER Branch
        Specifies the git branch to be cloned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $TargetDirectory,
        [Parameter(Mandatory)]
        [String] $Repo,
        [Parameter(Mandatory)]
        [String] $Branch
    )

    Push-Location $TargetDirectory

    $previousCommit = Invoke-Expression 'git rev-parse HEAD'
    $currentRepo = Invoke-Expression 'git config remote.origin.url'
    $currentBranch = Invoke-Expression 'git branch --show-current'

    $isRepoChanged = !($currentRepo -eq $Repo)
    $isBranchChanged = !($currentBranch -eq $Branch)

    # Change remote url if the repo is changed
    if ($isRepoChanged) { Invoke-Expression "git config remote.origin.url '$Repo'" }

    # Fetch and reset local repo if the repo or the branch is changed
    if ($isRepoChanged -or $isBranchChanged) {
        # Reset git fetch refs, so that it can fetch all branches (GH-3368)
        Invoke-Expression 'git config remote.origin.fetch ''+refs/heads/*:refs/remotes/origin/*'''
        # Fetch remote branch
        git_fetch -q --force origin "refs/heads/`"$Branch`":refs/remotes/origin/$Branch"
        # Checkout and track the branch
        git_checkout -q -B $Branch -t origin/$Branch
        # Reset branch HEAD
        Invoke-Expression "git reset -q --hard origin/$Branch"
    } else {
        git_pull -q
    }

    $res = $LASTEXITCODE
    if ($SHOW_UPDATE_LOG) {
        Invoke-Expression "git --no-pager log --no-decorate --format='tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset' '$previousCommit..HEAD'"
    }

    Pop-Location
    # TODO: Stop-ScoopExecution
    if ($res -ne 0) { abort 'Update failed.' }
}

function Update-ScoopLocalBucket {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [String[]] $Bucket)

    process {
        foreach ($b in $Bucket) {
            Write-UserMessage -Message "Updating '$b' bucket..."
            $loc = Find-BucketDirectory $b -Root

            # Make sure main bucket, which was downloaded as zip, will be properly "converted" into git
            if (($b -eq 'main') -and !(Test-Path "$loc\.git" -PathType Container)) {
                rm_bucket 'main'
                add_bucket 'main'
            }

            Push-Location $loc
            $previousCommit = Invoke-Expression 'git rev-parse HEAD'
            git_pull -q

            if ($SHOW_UPDATE_LOG) {
                Invoke-Expression "git --no-pager log --no-decorate --format='tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset' '$previousCommit..HEAD'"
            }
            Pop-Location
        }
    }
}

function Update-Scoop {
    <#
    .SYNOPSIS
        Update scoop itself and all buckets.
    #>
    [CmdletBinding()]
    param()

    # TODO: Stop-ScoopExecution
    if (!(Test-CommandAvailable -Command 'git')) { abort 'Scoop uses Git to update itself. Run ''scoop install git'' and try again.' }
    Write-UserMessage -Message 'Updating Scoop...'

    # TODO: CONFIG refactor adoption
    $configRepo = get_config 'SCOOP_REPO'
    $configBranch = get_config 'SCOOP_BRANCH'
    # TODO: Get rid of fullpath
    $currentDir = fullpath (versiondir 'scoop' 'current')

    # Defaults
    if (!$configRepo) {
        $configRepo = $DEFAULT_UPDATE_REPO
        set_config 'SCOOP_REPO' $DEFAULT_UPDATE_REPO | Out-Null
    }
    if (!$configBranch) {
        $configBranch = $DEFAULT_UPDATE_BRANCH
        set_config 'SCOOP_BRANCH' $DEFAULT_UPDATE_BRANCH | Out-Null
    }

    # Get when was scoop updated
    $lastUpdate = last_scoop_update
    if ($null -eq $lastUpdate) { $lastUpdate = [System.DateTime]::Now }
    $lastUpdate = $lastUpdate.ToString('s')

    # Clone new installation or pull changes
    if (!(Test-Path "$currentDir\.git" -PathType Container)) {
        Update-ScoopCoreClone -Repo $configRepo -Branch $configBranch -TargetDirectory $currentDir
    } else {
        Update-ScoopCorePull -Repo $configRepo -Branch $configBranch -TargetDirectory $currentDir
    }

    # Update buckets
    # Add main bucket if not already added
    if ((Get-LocalBucket) -notcontains 'main') {
        Write-UserMessage -Message 'The main bucket has been separated', 'Adding main bucket...'
        add_bucket 'main'
    }

    ensure_scoop_in_path
    shim "$currentDir\bin\scoop.ps1" $false

    Get-LocalBucket | Update-ScoopLocalBucket

    set_config 'lastupdate' [System.DateTime]::Now.ToString('o') | Out-Null
    Write-UserMessage -Message 'Scoop was updated successfully!' -Success
}


function Update-ScoopApplication {
    param($app, $global, $quiet = $false, $independent, $suggested, $use_cache = $true, $check_hash = $true)

    $old_version = current_version $app $global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global

    # re-use architecture, bucket and url from first install
    $architecture = ensure_architecture $install.architecture
    $url = $install.url
    $bucket = $install.bucket
    if ($null -eq $bucket) {
        $bucket = 'main'
    }

    if (!$independent) {
        # check dependencies
        $man = if ($url) { $url } else { $app }
        $deps = @(deps $man $architecture) | Where-Object { !(installed $_) }
        $deps | ForEach-Object { install_app $_ $architecture $global $suggested $use_cache $check_hash }
    }

    $version = latest_version $app $bucket $url
    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $(get-date) $quiet
        $check_hash = $false
    }

    if (!$force -and ($old_version -eq $version)) {
        if (!$quiet) {
            warn "The latest version of '$app' ($version) is already installed."
        }
        return
    }
    if (!$version) {
        # installed from a custom bucket/no longer supported
        error "No manifest available for '$app'."
        return
    }

    $manifest = manifest $app $bucket $url

    write-host "Updating '$app' ($old_version -> $version)"

    #region Workaround of #2220
    # Remove and replace whole region after proper fix
    Write-Host "Downloading new version"
    if (Test-Aria2Enabled) {
        dl_with_cache_aria2 $app $version $manifest $architecture $cachedir $manifest.cookie $true $check_hash
    } else {
        $urls = url $manifest $architecture

        foreach ($url in $urls) {
            dl_with_cache $app $version $url $null $manifest.cookie $true

            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $source = fullpath (cache_path $app $version $url)
                $ok, $err = check_hash $source $manifest_hash $(show_app $app $bucket)

                if (!$ok) {
                    error $err
                    if (test-path $source) {
                        # rm cached file
                        Remove-Item -force $source
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket "hash check failed")
                }
            }
        }
    }
    # There is no need to check hash again while installing
    $check_hash = $false
    #endregion Workaround of #2220

    $result = Uninstall-ScoopApplication -App $app -Global:$global
    if ($result -eq $false) { return }

    # Rename current version to .old if same version is installed
    if ($force -and ($old_version -eq $version)) {
        $dir = versiondir $app $old_version $global

        if (!(Test-Path "$dir/../_$version.old")) {
            Move-Item "$dir" "$dir/../_$version.old"
        } else {
            $i = 1
            While (Test-Path "$dir/../_$version.old($i)") {
                $i++
            }
            Move-Item "$dir" "$dir/../_$version.old($i)"
        }
    }

    if ($install.url) {
        $app = $install.url
    } elseif ($bucket) {
        $app = "$bucket/$app"
    }

    install_app $app $architecture $global $suggested $use_cache $check_hash
}
