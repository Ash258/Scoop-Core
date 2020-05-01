'core', 'git', 'buckets', 'install' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

# TODO: Change
$DEFAULT_UPDATE_REPO = 'https://github.com/lukesampson/scoop'
$DEFAULT_UPDATE_BRANCH = 'master'
# TODO: CONFIG adopt refactor
$SHOW_UPDATE_LOG = get_config 'show_update_log' $true
$GIT_CMD_LOG = "git --no-pager log --no-decorate --format='tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset' --grep='\[scoop\|shovel skip\]' --invert-grep"

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
    Move-Item $newDir $TargetDirectory
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
        Invoke-Expression "$GIT_CMD_LOG '$previousCommit..HEAD'"
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
                Invoke-Expression "$GIT_CMD_LOG '$previousCommit..HEAD'"
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
    $par = @{ 'Repo' = $configRepo; 'Branch' = $configBranch; 'TargetDirectory' = $currentDir }
    if (!(Test-Path "$currentDir\.git" -PathType Container)) {
        Update-ScoopCoreClone @par
    } else {
        Update-ScoopCorePull @par
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

    set_config 'lastupdate' ([System.DateTime]::Now.ToString('o')) | Out-Null
    Write-UserMessage -Message 'Scoop was updated successfully!' -Success
}


function Update-App {
    <#
    .SYNOPSIS
        Update scoop installed application
    .PARAMETER App
        Specifies the application name.
    .PARAMETER Global
        Specifies globally installe application.
    .PARAMETER Quiet
        Specifies supressing more verbose output.
    .PARAMETER Independent
        Specifies to not update dependent applications.
    .PARAMETER Suggested
        Specifies applications to be shown to user as suggestions after update.
    .PARAMETER SkipCache
        Specifies to skip use of download cache.
    .PARAMETER SkipHashCheck
        Specifies to not verify downloaded files using hash comparison.
    #>
    [CmdletBinding()]
    param(
        [String] $App,
        [Switch] $Global,
        [Switch] $Quiet,
        [Switch] $Independent,
        $Suggested,
        [Switch] $SkipCache,
        [Switch] $SkipHashCheck
    )

    $oldVersion = current_version $App $Global
    $oldManifest = installed_manifest $App $oldVersion $Global
    $install = install_info $App $oldVersion $Global

    # Old variables
    $check_hash = !$SkipHashCheck
    $use_cache = !$SkipCache
    $old_version = $old_version
    $old_manifest = $oldManifest

    # Re-use architecture, bucket and url from first install
    $architecture = ensure_architecture $install.architecture
    $url = $install.url
    $bucket = $install.bucket
    if ($null -eq $bucket) { $bucket = 'main' }

    # Check dependencies
    if (!$Independent) {
        $man = if ($url) { $url } else { $app }
        $deps = @(deps $man $architecture) | Where-Object { !(installed $_) }
        $deps | ForEach-Object { install_app $_ $architecture $Global $Suggested $SkipCache (!$SkipHashCheck) }
    }

    $version = latest_version $App $bucket $url
    if ($version -eq 'nightly') {
        $version = nightly_version (Get-Date) $Quiet
        $SkipHashCheck = $true
    }

    # TODO: Could this ever happen?
    if (!$Force -and ($oldVersion -eq $version)) {
        if (!$quiet) { Write-UserMessage -Message "The Latest version of '$App' ($version) is already installed." -Warning }
        return
    }

    # TODO:???
    # TODO: Case when bucket no longer have this application?
    if (!$version) {
        Write-UserMessage -Message "No manifest available for '$App'" -Err
        return
    }

    $manifest = manifest $App $bucket $url

    Write-UserMessage -Message "Updating '$App' ($oldVersion -> $version)"

    #region Workaround of #2220
    # Remove and replace whole region after proper implementation
    Write-Host 'Downloading new version'

    if (Test-Aria2Enabled) {
        dl_with_cache_aria2 $App $version $manifest $architecture $SCOOP_CACHE_DIRECTORY $manifest.cookie $true (!$SkipHashCHeck)
    } else {
        $urls = url $manifest $architecture

        foreach ($url in $urls) {
            dl_with_cache $App $version $url $null $manifest.cookie $true

            if (!$SkipHashCheck) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                # TODO: Get rid of fullpath
                $source = fullpath (cache_path $App $version $url)
                $ok, $err = check_hash $source $manifest_hash (show_app $App $bucket)

                if (!$ok) {
                    Write-UserMessage -Message $err -Err

                    # Remove cached file
                    if (Test-Path $source) { Remove-Item $source -Force }
                    if ($url -like '*sourceforge.net*') {
                        Write-UserMessage -Message 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.' -Warning
                    }
                    # TODO: Stop-ScoopExecution
                    abort (new_issue_msg $App $bucket 'hash check failed')
                }
            }
        }
    }

    # There is no need to check hash again while installing
    $SkipHashCheck = $true
    #endregion Workaround of #2220

    $result = Uninstall-ScoopApplication -App $App -Global:$Global
    if ($result -eq $false) { return }

    # Rename current version to .old if same version is installed
    if ($Force -and ($oldVersion -eq $version)) {
        $dir = versiondir $App $oldVersion $Global

        $old = "$dir/../_$version.old"
        if (Test-Path $old -PathType Container) {
            $i = 1
            while (Test-Path "$old($i)") { ++$i }
            Move-Item $dir "$old($i)"
        } else {
            Move-Item $dir $old
        }
    }

    $toUpdate = if ($install.url) { $install.url } else { "$bucket/$App" }

    # TODO: Try catch
    install_app $toUpdate $architecture $Global $Suggested (!$SkipCache) (!$SkipHashCheck)
}
