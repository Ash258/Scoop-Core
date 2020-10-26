# TODO: Core import is messing up with download progress
'Helpers' | ForEach-Object { #, 'core' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

#region helpers
function Test-7zipRequirement {
    [CmdletBinding(DefaultParameterSetName = 'URL')]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'URL')]
        [AllowNull()]
        [String[]] $URL,
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [String] $File
    )

    if (!$File -and ($null -eq $URL)) { return $false }


    if ($URL) {
        # For dependencies resolving
        if (get_config '7ZIPEXTRACT_USE_EXTERNAL' $false) {
            return $false
        } else {
            return ($URL | Where-Object { Test-7zipRequirement -File $_ }).Count -gt 0
        }
    } else {
        return $File -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
    }
}

function Test-LessmsiRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory)]
        [AllowNull()]
        [String[]] $URL
    )

    if ($null -eq $URL) { return $false }

    if (get_config 'MSIEXTRACT_USE_LESSMSI' $false) {
        return ($URL | Where-Object { $_ -match '\.msi$' }).Count -gt 0
    } else {
        return $false
    }
}

function Test-ZstdRequirement {
    [CmdletBinding(DefaultParameterSetName = 'URL')]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'URL')]
        [String[]] $URL,
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [String] $File
    )

    if ($URL) {
        return ($URL | Where-Object { Test-ZstdRequirement -File $_ }).Count -gt 0
    } else {
        return $File -match '\.zst$'
    }
}
#endregion helpers

function Expand-7zipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [ValidateSet('All', 'Skip', 'Rename')]
        [String] $Overwrite,
        [Switch] $Removal
    )

    begin {
        if (get_config '7ZIPEXTRACT_USE_EXTERNAL' $false) {
            try {
                $7zPath = (Get-Command '7z' -CommandType Application | Select-Object -First 1).Source
            } catch [System.Management.Automation.CommandNotFoundException] {
                Set-TerminatingError -Title "Ignore|-Cannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
            }
        } else {
            $7zPath = Get-HelperPath -Helper '7zip'
        }
    }

    process {
        $logPath = Split-Path $Path -Parent | Join-Path -ChildPath '7zip.log'
        $argList = @('x', "`"$Path`"", "-o`"$DestinationPath`"", '-y')
        $isTar = ((strip_ext $Path) -match '\.tar$') -or ($Path -match '\.t[abgpx]z2?$')

        if (!$isTar -and $ExtractDir) { $argList += "-ir!`"$ExtractDir\*`"" }
        if ($Switches) { $argList += (-split $Switches) }

        switch ($Overwrite) {
            'All' { $argList += '-aoa' }
            'Skip' { $argList += '-aos' }
            'Rename' { $argList += '-aou' }
        }

        try {
            $status = Invoke-ExternalCommand $7zPath $argList -LogPath $logPath
        } catch [System.Management.Automation.ParameterBindingException] {
            Set-TerminatingError -Title 'Ignore|-''7zip'' is not installed or cannot be used'
        }

        if (!$status) {
            Set-TerminatingError -Title "Decompress error|-Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)"
        }
        if (!$isTar -and $ExtractDir) {
            movedir (Join-Path $DestinationPath $ExtractDir) $DestinationPath | Out-Null
        }
        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        if ($isTar) {
            # Check for tar
            $tarStatus = Invoke-ExternalCommand $7zPath @('l', "`"$Path`"") -LogPath $logPath
            if ($tarStatus) {
                # Get inner tar file name
                $tarFile = (Get-Content -Path $logPath)[-4] -replace '.{53}(.*)', '$1'
                Expand-7zipArchive -Path (Join-Path $DestinationPath $tarFile) -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
            } else {
                Set-TerminatingError -Title "Decompress error|-Failed to list files in $Path.`nNot a 7-Zip supported archive file."
            }
        }

        # Remove original archive file
        if ($Removal) { Remove-Item $Path -Force }
    }
}

function Expand-MsiArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [Switch] $Removal
    )

    process {
        $DestinationPath = $DestinationPath.TrimEnd('\')
        if ($ExtractDir) {
            $originalDestination = $DestinationPath
            $DestinationPath = Join-Path $DestinationPath '_tmp'
        }

        if ((get_config 'MSIEXTRACT_USE_LESSMSI' $false)) {
            $msiPath = Get-HelperPath -Helper 'Lessmsi'
            $argList = @('x', "`"$Path`"", "`"$DestinationPath\\`"")
        } else {
            $msiPath = 'msiexec.exe'
            $argList = @('/a', "`"$Path`"", '/qn', "TARGETDIR=`"$DestinationPath\\SourceDir`"")
        }

        $logPath = Split-Path $Path -Parent | Join-Path -ChildPath 'msi.log'
        if ($Switches) { $argList += (-split $Switches) }

        $status = Invoke-ExternalCommand $msiPath $argList -LogPath $logPath

        if (!$status) {
            Set-TerminatingError -Title "Decompress error|-Failed to extract files from $Path.`nLog file:`n  $(friendly_path $logPath)"
        }

        $sourceDir = Join-Path $DestinationPath 'SourceDir'
        if ($ExtractDir -and (Test-Path $sourceDir)) {
            movedir (Join-Path $sourceDir $ExtractDir) $originalDestination | Out-Null
            Remove-Item $DestinationPath -Recurse -Force
        } elseif ($ExtractDir) {
            movedir (Join-Path $DestinationPath $ExtractDir) $originalDestination | Out-Null
            Remove-Item $DestinationPath -Recurse -Force
        } elseif (Test-Path $sourceDir) {
            movedir $sourceDir $DestinationPath | Out-Null
        }

        # ??
        $fnamePath = Join-Path $DestinationPath (fname $Path)
        if (($DestinationPath -ne (Split-Path $Path)) -and (Test-Path $fnamePath)) { Remove-Item $fnamePath -Force }

        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        # Remove original archive file
        if ($Removal) { Remove-Item $Path -Force }
    }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [Switch] $Removal
    )

    process {
        $logPath = Split-Path $Path -Parent | Join-Path -ChildPath 'innounp.log'
        $argList = @('-x', "-d`"$DestinationPath`"", "`"$Path`"", '-y')

        switch -Regex ($ExtractDir) {
            '^[^{].*' { $argList += "-c{app}\$ExtractDir" }
            '^{.*' { $argList += "-c$ExtractDir" }
            default { $argList += '-c{app}' }
        }
        if ($Switches) { $argList += (-split $Switches) }

        try {
            # TODO: Find out extract_dir issue.
            # When there is no specified directory in archive innounp will just exit with 0 and version of file
            $status = Invoke-ExternalCommand (Get-HelperPath -Helper 'Innounp') $argList -LogPath $logPath
        } catch [System.Management.Automation.ParameterBindingException] {
            Set-TerminatingError -Title 'Ignore|-''innounp'' is not installed or cannot be used'
        }
        if (!$status) {
            Set-TerminatingError -Title "Decompress error|-Failed to extract files from $Path.`nLog file:`n  $(friendly_path $logPath)"
        }
        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        # Remove original archive file
        if ($Removal) { Remove-Item $Path -Force }
    }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Switch] $Removal
    )

    process {
        if ($ExtractDir) {
            $originalDestination = $DestinationPath
            $DestinationPath = Join-Path $DestinationPath '_tmp'
        }

        # All methods to unzip the file require .NET4.5+
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            try {
                [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
            } catch [System.IO.PathTooLongException] {
                # Try to fall back to 7zip if path is too long
                if (Test-HelperInstalled -Helper '7zip') {
                    Expand-7zipArchive $Path $DestinationPath -Removal:$Removal
                    return
                } else {
                    Set-TerminatingError -Title "Ignore|-Unzip failed: Windows cannot handle long paths in this zip file.`nRun 'scoop install 7zip' and try again."
                }
            } catch [System.IO.IOException] {
                if (Test-HelperInstalled -Helper '7zip') {
                    Expand-7zipArchive $Path $DestinationPath -Removal:$Removal
                    return
                } else {
                    Set-TerminatingError -Title "Ignore|-Unzip failed: Windows cannot handle the file names in this zip file.`nRun 'scoop install 7zip' and try again."
                }
            } catch {
                Set-TerminatingError -Title "Decompress error|-Unzip failed: $_"
            }
        } else {
            # Use Expand-Archive to unzip in PowerShell 5+
            # Compatible with Pscx (https://github.com/Pscx/Pscx)
            Microsoft.PowerShell.Archive\Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
        }

        if ($ExtractDir) {
            movedir (Join-Path $DestinationPath $ExtractDir) $originalDestination | Out-Null
            Remove-Item $DestinationPath -Recurse -Force
        }
        # Remove original archive file
        if ($Removal) { Remove-Item $Path -Force }
    }
}

function Expand-DarkArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String] $DestinationPath = (Split-Path $Path),
        [Parameter(ValueFromRemainingArguments = $true)]
        [String] $Switches,
        [Switch] $Removal
    )

    process {
        $logPath = Split-Path $Path -Parent | Join-Path -ChildPath 'dark.log'
        $argList = @('-nologo', "-x `"$DestinationPath`"", "`"$Path`"")
        if ($Switches) { $argList += (-split $Switches) }

        try {
            $status = Invoke-ExternalCommand (Get-HelperPath -Helper 'Dark') $argList -LogPath $logPath
        } catch [System.Management.Automation.ParameterBindingException] {
            Set-TerminatingError -Title 'Ignore|-''dark'' is not installed or cannot be used'
        }

        if (!$status) {
            Set-TerminatingError -Title "Decompress error|-Failed to extract files from $Path.`nLog file:`n  $(friendly_path $logPath)"
        }
        if (Test-Path $logPath) { Remove-Item $logPath -Force }

        # Remove original archive file
        if ($Removal) { Remove-Item $Path -Force }
    }
}

function Expand-ZstdArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String[]] $Path,
        [Parameter(Position = 1)]
        [Alias('ExtractTo')]
        [String[]] $DestinationPath,
        [String[]] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [Switch] $Overwrite,
        [Switch] $Removal
    )

    begin {
        $argList = @('-d')
        $zstdPath = Get-HelperPath -Helper 'Zstd'
        if ($null -eq $zstdPath) { throw 'Ignore|-''zstd'' is not installed or cannot be used' }
        if ($Switches) { $argList += (-split $Switches) }
        if ($Overwrite) { $argList += '-f' }
    }

    process {
        for ($index = 0; $index -lt $Path.Count, ++$index) {
            $currentPath = $Path[$index]
            $currentLogPath = Split-Path -Path $currentPath | Join-Path -ChildPath 'zstd.log'
            $currentArgList = $argList
            $currentDestinationPath = if ($null -eq $DestinationPath[$index]) { $DestinationPath[-1] } else { $DestinationPath[$index] }
            $currentExtractDir = $null
            if ($ExtractDir) {
                $currentExtractDir = if ($null -eq $ExtractDir[$index]) { $ExtractDir[-1] } else { $ExtractDir[$index] }
            }
            $currentArgList += $currentPath, "-o ""$currentDestinationPath"""

            $status = Invoke-ExternalCommand -Path $zstdPath -ArgumentList $currentArgList -LogPath $currentLogPath
            if (!$status) {
                throw "Decompress error|-Failed to extract files from $currentPath.`nLog file:`n  $(friendly_path $currentLogPath)"
            }

            Remove-Item -Path $currentLogPath -ErrorAction SilentlyContinue -Force
        }
    }

    end {
        if ($Removal) { Remove-Item -Path $Path -ErrorAction SilentlyContinue -Force }
    }
}

#region Deprecated
function extract_7zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-7zipArchive'
    Expand-7zipArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function extract_msi($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-MsiArchive'
    Expand-MsiArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function unpack_inno($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-InnoArchive'
    Expand-InnoArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function extract_zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-ZipArchive'
    Expand-ZipArchive -Path $path -DestinationPath $to -Removal:$removal
}
#endregion Deprecated
