<#
Diagnostic tests.
Return $true if the test passed, otherwise $false.
Use 'warn' to highlight the issue, and follow up with the recommended actions to rectify.
#>

'buckets', 'decompress' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

function check_windows_defender($global) {
    $defender = get-service -name WinDefend -errorAction SilentlyContinue
    if ($defender -and $defender.status) {
        if ($defender.status -eq [system.serviceprocess.servicecontrollerstatus]::running) {
            if (Test-CommandAvailable Get-MpPreference) {
                $installPath = $scoopdir;
                if ($global) { $installPath = $globaldir; }

                $exclusionPath = (Get-MpPreference).exclusionPath
                if (!($exclusionPath -contains $installPath)) {
                    warn "Windows Defender may slow down or disrupt installs with realtime scanning."
                    write-host "  Consider running:"
                    write-host "    sudo Add-MpPreference -ExclusionPath '$installPath'"
                    write-host "  (Requires 'sudo' command. Run 'scoop install sudo' if you don't have it.)"
                    return $false
                }
            }
        }
    }
    return $true
}

function check_main_bucket {
    if ((Get-LocalBucket) -notcontains 'main') {
        warn 'Main bucket is not added.'
        Write-Host "  run 'scoop bucket add main'"

        return $false
    }

    return $true
}

function check_long_paths {
    $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction SilentlyContinue -Name 'LongPathsEnabled'
    if (!$key -or ($key.LongPathsEnabled -eq 0)) {
        warn 'LongPaths support is not enabled.'
        Write-Host "You can enable it with running:"
        Write-Host "    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1"

        return $false
    }

    return $true
}

function check_envs_requirements {
    $result = $true
    if (($null -eq $env:COMSPEC) -or (!(Test-Path $env:COMSPEC -PathType Leaf))) {
        Write-UserMessage -Message '$env:COMSPEC is not configured' -Warning
        Write-Host "    By default the variable should points to the cmd.exe in Windows: '%SystemRoot%\system32\cmd.exe'."

        $result = $false
    }



    return $result
}

function check_helpers_installed {
    $result = $true

    if (!(Test-HelperInstalled -Helper 7zip)) {
        Write-UserMessage -Message "'7zip' is not installed! It's required for unpacking most programs. Please Run 'scoop install 7zip' or 'scoop install 7zip-zstd'." -Warning
        $result = $false
    }

    if (!(Test-HelperInstalled -Helper Innounp)) {
        Write-UserMessage -Message "'innounp' is not installed! It's required for unpacking InnoSetup files. Please run 'scoop install innounp'." -Warning
        $result = $false
    }

    if (!(Test-HelperInstalled -Helper Dark)) {
        Write-UserMessage -Message  "'dark' is not installed! It's required for unpacking installers created with the WiX Toolset. Please run 'scoop install dark' or 'scoop install wixtoolset'." -Warning
        $result = $false
    }

    if (!(Test-HelperInstalled -Helper LessMsi)) {
        Write-UserMessage -Message  "'lessmsi' is not installed! It's required for unpacking msi installers. Please run 'scoop install lessmsi'." -Warning
        $result = $false
    }

    return $result
}

function check_drive {
    $result = $true

    if ((New-Object System.IO.DriveInfo($SCOOP_GLOBAL_ROOT_DIRECTORY)).DriveFormat -ne 'NTFS') {
        Write-UserMessage -Message "Scoop requires an NTFS volume to work! Please point `$env:SCOOP_GLOBAL or 'globalPath' variable in '~/.config/scoop/config.json' to another Drive." -Warning
        $result = $false
    }

    if ((New-Object System.IO.DriveInfo($SCOOP_ROOT_DIRECTORY)).DriveFormat -ne 'NTFS') {
        Write-UserMessage -Message "Scoop requires an NTFS volume to work! Please point `$env:SCOOP or 'rootPath' variable in '~/.config/scoop/config.json' to another Drive." -Warning
        $result = $false
    }

    return $result
}
