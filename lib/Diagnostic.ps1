<#
Diagnostic tests.
Return $true if the test passed, otherwise $false.
Use 'Write-UserMessage -Warning' to highlight the issue, and follow up with the recommended actions to rectify.
#>

'core', 'buckets', 'decompress', 'Git', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Test-DiagDrive {
    <#
    .SYNOPSIS
        Test disk drive requirements/configuration.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = $true

    if ((New-Object System.IO.DriveInfo($SCOOP_GLOBAL_ROOT_DIRECTORY)).DriveFormat -ne 'NTFS') {
        Write-UserMessage -Message 'Scoop requires an NTFS volume to work!' -Warning
        Write-UserMessage -Message '  Please configure SCOOP_GLOBAL environment variable to NTFS volume'
        $result = $false
    }

    if ((New-Object System.IO.DriveInfo($SCOOP_ROOT_DIRECTORY)).DriveFormat -ne 'NTFS') {
        Write-UserMessage -Message 'Scoop requires an NTFS volume to work!' -Warning
        Write-UserMessage -Message '  Please install scoop to NTFS volume'
        $result = $false
    }

    return $result
}

function Test-DiagWindowsDefender {
    <#
    .SYNOPSIS
        Test windows defender exclusions.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Switch] $Global)

    if (Test-IsUnix) { return $true }

    $defender = Get-Service -Name 'WinDefend' -ErrorAction 'SilentlyContinue'
    if ((is_admin) -and ($defender -and $defender.Status) -and ($defender.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)) {
        if (Test-CommandAvailable -Command 'Get-MpPreference') {
            $installPath = if ($Global) { $SCOOP_GLOBAL_ROOT_DIRECTORY } else { $SCOOP_ROOT_DIRECTORY }
            $exclusionPath = (Get-MpPreference).ExclusionPath

            if ($exclusionPath -notcontains $installPath) {
                Write-UserMessage -Message 'Windows Defender may slow down or disrupt installs with realtime scanning.' -Warning

                Write-UserMessage -Message @(
                    '  Fixable with running following command in elevated prompt:'
                    "    Add-MpPreference -ExclusionPath '$installPath'"
                )

                return $false
            }
        }
    }

    return $true
}

function Test-DiagMainBucketAdded {
    <#
    .SYNOPSIS
        Test if main bucket was added after migration from core repository.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ((Get-LocalBucket) -notcontains 'main') {
        Write-UserMessage -Message '''main'' bucket is not added.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command in elevated prompt:'
            '    scoop bucket add main'
        )

        return $false
    }

    return $true
}

function Test-DiagLongPathEnabled {
    <#
    .SYNOPSIS
        Test if long paths option is enabled.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (Test-IsUnix) { return $true }

    # Verify supported windows version
    if ([System.Environment]::OSVersion.Version.Major -lt 10 -or [System.Environment]::OSVersion.Version.Build -lt 1607) {
        Write-UserMessage -Message 'LongPath configuration is not supported in older Windows versions' -Warning
        return $false
    }

    $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -ErrorAction 'SilentlyContinue'
    if (!$key -or ($key.LongPathsEnabled -eq 0)) {
        Write-UserMessage -Message 'LongPaths support is not enabled.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command in elevated prompt:'
            '    Set-ItemProperty ''HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'' -Name ''LongPathsEnabled'' -Value 1'
        )

        return $false
    }

    return $true
}

function Test-DiagEnvironmentVariable {
    <#
    .SYNOPSIS
        Test if scoop's related environment variables are defined.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = $true

    if (Test-IsUnix) {
        # Unix "comspec"
        if (!(Test-Path $env:SHELL -PathType 'Leaf')) {
            Write-UserMessage -Message '''SHELL'' environment variable is not configured' -Warning
            $result = $false
        }
    } else {
        # Windows Comspec
        if (($null -eq $env:COMSPEC) -or (!(Test-Path $env:COMSPEC -PathType 'Leaf'))) {
            Write-UserMessage -Message '''COMSPEC'' environment variable is not configured' -Warning
            Write-UserMessage -Message @(
                '  By default the variable should points to the cmd.exe in Windows: ''%SystemRoot%\system32\cmd.exe''.'
                '  Fixable with running following command in elevated prompt:'
                '    [Environment]::SetEnvironmentVariable(''COMSPEC'', "$env:SystemRoot\system32\cmd.exe", ''Machine'')'
            )
            $result = $false
        }
    }

    # Scoop ENV
    if (!$env:SCOOP) {
        Write-UserMessage -Message '''SCOOP'' environment variable is not configured' -Warning
        Write-UserMessage -Message @(
            '  SCOOP environment should be set as it is widely used by users and documentation to reference scoop installation directory'
            '  Fixable with running following command:'
            "    [Environment]::SetEnvironmentVariable('SCOOP', '$SCOOP_ROOT_DIRECTORY', 'User')"
        )
        $result = $false
    }

    if ($env:SCOOP -ne $SCOOP_ROOT_DIRECTORY) {
        Write-UserMessage -Message '''SCOOP'' environment variable should be set to actual scoop installation location' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            "    [Environment]::SetEnvironmentVariable('SCOOP', '$SCOOP_ROOT_DIRECTORY', 'User')"
        )
        $result = $false
    }

    # Does not make sense to have global defined on user level
    $value = [System.Environment]::GetEnvironmentVariable('SCOOP_GLOBAL', 'User')
    if ($value) {
        Write-UserMessage -Message '''SCOOP_GLOBAL'' environment variable is configured on User level' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            "    [Environment]::SetEnvironmentVariable('SCOOP_GLOBAL', '$value', 'Machine')"
        )

        $result = $false
    }

    return $result
}

function Test-DiagHelpersInstalled {
    <#
    .SYNOPSIS
        Test if all widely used helpers are installed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = $true

    if (!(Test-HelperInstalled -Helper '7zip')) {
        Write-UserMessage -Message '''7-Zip'' not installed!. It is essential component for most of the manifests.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            '    scoop install 7zip'
            '  or you can configure to use 7-Zip not installed by scoop:'
            '    scoop config ''7ZIPEXTRACT_USE_EXTERNAL'' $true'
        )

        $result = $false
    }

    if (!(Test-HelperInstalled -Helper 'Innounp')) {
        Write-UserMessage -Message '''innounp'' is not installed! It is essential component for extraction of InnoSetup based installers.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            '    scoop install innounp'
        )

        $result = $false
    }

    if (!(Test-HelperInstalled -Helper 'Dark')) {
        Write-UserMessage -Message '''dark'' is not installed! It is essential component for extraction of WiX Toolset based installers.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            '    scoop install dark'
            '  or'
            '    scoop install wixtoolset'
        )

        $result = $false
    }

    if (!(Test-HelperInstalled -Helper 'LessMsi')) {
        Write-UserMessage -Message '''lessmsi'' is not installed! It is essential component for extraction of msi installers.' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            '    scoop install lessmsi'
        )

        $result = $false
    }

    # TODO: Consider checking for zstd if it will be used by more vendors

    return $result
}

function Test-DiagConfig {
    <#
    .SYNOPSIS
        Test if various recommended scoop configurations are set correctly.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = $true
    if (!(get_config 'MSIEXTRACT_USE_LESSMSI' $false)) {
        Write-UserMessage -Message '''lessmsi'' should be used for extraction of msi installers!' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            '    scoop install lessmsi; scoop config MSIEXTRACT_USE_LESSMSI $true'
        )

        $result = $false
    }

    return $result
}

function Test-DiagCompletionRegistered {
    <#
    .SYNOPSIS
        Test if native completion is imported.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $module = Get-Module 'Scoop-Completion'

    if (($null -eq $module) -or ($module.Author -notlike 'Jakub*')) {
        $path = Join-Path $PSScriptRoot '..\supporting\completion\Scoop-Completion.psd1' -Resolve
        Write-UserMessage -Message 'Native tab completion module is not imported' -Warning
        Write-UserMessage -Message @(
            '  Consider importing native module for automatic commands/parameters completion:'
            "    Add-Content `$PROFILE 'Import-Module ''$path'' -ErrorAction SilentlyContinue'"
        )

        return $false
    }

    return $true
}

function Test-DiagShovelAdoption {
    <#
    .SYNOPSIS
        Test if shovel implementation was fully adopted by user.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $shimDirectory = shimdir $false
    $shovels = Get-ChildItem $shimDirectory -Filter 'shovel.*'
    if ($shovels.Count -le 2) {
        Write-UserMessage -Message 'Shovel executables are not registered' -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following command:'
            "    Get-ChildItem '$shimDirectory' -Filter 'scoop.*' | Copy-Item -Destination { Join-Path `$_.Directory.FullName ((`$_.BaseName -replace 'scoop', 'shovel') + `$_.Extension) }"
        )

        return $false
    }

    return $true
}

function Test-MainBranchAdoption {
    <#
    .SYNOPSIS
        Test if shovel and all locally added buckets were switched to main branch.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $verdict = $true
    $br = get_config 'SCOOP_BRANCH'
    $scoopHome = versiondir 'scoop' 'current'
    $fix = @(
        '  Fixable with running following command:'
        '    scoop update'
    )

    # Shovel - empty config
    if ($null -eq $br) {
        Write-UserMessage -Message '''SCOOP_BRANCH'' configuration option is not configured.' -Warning
        Write-UserMessage -Message $fix

        $verdict = $false
    } elseif (($br -eq 'master') -or (Invoke-GitCmd -Repository $scoopHome -Command 'branch' -Argument '--show-current') -eq 'master') {
        # Shovel - master config, current master branch
        Write-UserMessage -Message 'Default branch was changed to ''main''.' -Warning
        Write-UserMessage -Message $fix

        $verdict = $false
    }

    $toFix = @()
    foreach ($b in Get-LocalBucket) {
        $path = Find-BucketDirectory -Name $b -Root
        $branches = Invoke-GitCmd -Repository $path -Command 'branch' -Argument '--all'
        $current = Invoke-GitCmd -Repository $path -Command 'branch' -Argument '--show-current'

        if (($branches -like '* remotes/origin/main') -and ($current -eq 'master')) {
            $toFix += @{ 'name' = $b; 'path' = $path }

            $verdict = $false
        }
    }

    if (($verdict -eq $false) -and ($toFix.Count -gt 0)) {
        Write-UserMessage -Message "Locally added buckets should be reconfigured to main branch." -Warning
        Write-UserMessage -Message @(
            '  Fixable with running following commands:'
            ($toFix | ForEach-Object { "    git -C '$($_.path)' checkout main" })
        )
    }

    return $verdict
}

function Test-ScoopConfigFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $verdict = $true

    if (!(Test-Path $SCOOP_CONFIGURATION_FILE)) {
        Write-UserMessage -Message 'Configuration file does not exists.' -Warn
        Write-UserMessage -Message @(
            '  Fixable with running following commands:'
            "    scoop update"
        )

        $verdict = $false
    }

    $old = Join-Path $env:USERPROFILE '.scoop'
    if (Test-Path $old) {
        Write-UserMessage -Message 'Old configuration file exists. It should be removed' -Warn
        Write-UserMessage -Message @(
            '  Fixable with running following commands:'
            "    Remove-Item '$old'"
        )

        $verdict = $false
    }

    $toFix = @()
    'rootPath', 'globalPath', 'cachePath' | ForEach-Object {
        $c = get_config $_
        if ($c) {
            $toFix += $_

            $verdict = $false
        }
    }
    if ($toFix.Count -gt 0) {
        Write-UserMessage -Message 'Some configuration options are no longer supported.' -Warn
        Write-UserMessage -Message @(
            '  Fixable with running following commands:'
            ($toFix | ForEach-Object { "    scoop config rm '$_'" })
        )
    }

    return $verdict
}
