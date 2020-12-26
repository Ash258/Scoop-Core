<#
Diagnostic tests.
Return $true if the test passed, otherwise $false.
Use 'Write-UserMessage -Warning' to highlight the issue, and follow up with the recommended actions to rectify.
#>

'core', 'buckets', 'decompress', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Test-Drive {
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

function Test-WindowsDefender {
    <#
    .SYNOPSIS
        Test windows defender exclusions.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Switch] $Global)

    $defender = Get-Service -Name 'WinDefend' -ErrorAction 'SilentlyContinue'
    if (($defender -and $defender.Status) -and ($defender.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)) {
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

function Test-MainBucketAdded {
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

function Test-LongPathEnabled {
    <#
    .SYNOPSIS
        Test if long paths option is enabled.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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

function Test-EnvironmentVariable {
    <#
    .SYNOPSIS
        Test if scoop's related environment variables are defined.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = $true

    # Comspec
    if (($null -eq $env:COMSPEC) -or (!(Test-Path $env:COMSPEC -PathType 'Leaf'))) {
        Write-UserMessage -Message '''COMSPEC'' is not configured' -Warning
        Write-UserMessage -Message @(
            '  By default the variable should points to the cmd.exe in Windows: ''%SystemRoot%\system32\cmd.exe''.'
            '  Fixable with running following command in elevated prompt:'
            '    [Environment]::SetEnvironmentVariable(''COMSPEC'', "$env:SystemRoot\system32\cmd.exe", ''Machine'')'
        )
        $result = $false
    }

    # Scoop ENV
    if (!$env:SCOOP) {
        Write-UserMessage -Message '''SCOOP'' is not configured' -Warning
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

    return $result
}

function Test-HelpersInstalled {
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

    return $result
}

function Test-Config {
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

function Test-CompletionRegistered {
    <#
    .SYNOPSIS
        Test if native completion is imported.
    #>
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
