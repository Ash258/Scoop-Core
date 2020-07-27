'core', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Test-7zipRequirement {
    [CmdletBinding(DefaultParameterSetName = 'URL')]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'URL')]
        [String[]] $URL,
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [String] $File
    )

    if (get_config '7ZIPEXTRACT_USE_EXTERNAL' $false) { return $false }

    if ($URL) {
        return ($URL | Where-Object { Test-7zipRequirement -File $_ }).Count -gt 0
    } else {
        return $File -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
    }
}

function Test-LessmsiRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory)]
        [String[]] $URL
    )

    if (get_config 'MSIEXTRACT_USE_LESSMSI' $false) {
        return ($URL | Where-Object { $_ -match '\.msi$' }).Count -gt 0
    } else {
        return $false
    }
}

function Expand-7zipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [ValidateSet('All', 'Skip', 'Rename')]
        [String] $Overwrite,
        [Switch] $Removal
    )

    if (get_config '7ZIPEXTRACT_USE_EXTERNAL' $false) {
        try {
            $7zPath = (Get-Command '7z' -CommandType Application | Select-Object -First 1).Source
        } catch [System.Management.Automation.CommandNotFoundException] {
            Set-TerminatingError -Title "Ignore|-Cannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
        }
    } else {
        $7zPath = Get-HelperPath -Helper 7zip
    }

    $LogPath = Split-Path $Path -Parent | Join-Path -ChildPath '7zip.log'
    $ArgList = @('x', "`"$Path`"", "-o`"$DestinationPath`"", '-y')
    $IsTar = ((strip_ext $Path) -match '\.tar$') -or ($Path -match '\.t[abgpx]z2?$')
    if (!$IsTar -and $ExtractDir) {
        $ArgList += "-ir!`"$ExtractDir\*`""
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }

    switch ($Overwrite) {
        'All' { $ArgList += '-aoa' }
        'Skip' { $ArgList += '-aos' }
        'Rename' { $ArgList += '-aou' }
    }

    try {
        $Status = Invoke-ExternalCommand $7zPath $ArgList -LogPath $LogPath
    } catch [System.Management.Automation.ParameterBindingException] {
        Write-UserMessage -Message '''7zip'' is not installed or cannot be used' -Err
    }

    if (!$Status) {
        Set-TerminatingError -Title "Decompress Error|-Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)"
    }
    if (!$IsTar -and $ExtractDir) {
        movedir (Join-Path $DestinationPath $ExtractDir) $DestinationPath | Out-Null
    }
    if (Test-Path $LogPath) { Remove-Item $LogPath -Force }

    if ($IsTar) {
        # Check for tar
        $Status = Invoke-ExternalCommand $7zPath @('l', "`"$Path`"") -LogPath $LogPath
        if ($Status) {
            $TarFile = (Get-Content -Path $LogPath)[-4] -replace '.{53}(.*)', '$1' # get inner tar file name
            Expand-7zipArchive -Path (Join-Path $DestinationPath $TarFile) -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
        } else {
            Set-TerminatingError -Title "Decompress Error|-Failed to list files in $Path.`nNot a 7-Zip supported archive file."
        }
    }

    # Remove original archive file
    if ($Removal) { Remove-Item $Path -Force }
}

function Expand-MsiArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [Switch] $Removal
    )

    $DestinationPath = $DestinationPath.TrimEnd('\')
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = Join-Path $DestinationPath '_tmp'
    }
    if ((get_config 'MSIEXTRACT_USE_LESSMSI' $false)) {
        $MsiPath = Get-HelperPath -Helper Lessmsi
        $ArgList = @('x', "`"$Path`"", "`"$DestinationPath\\`"")
    } else {
        $MsiPath = 'msiexec.exe'
        $ArgList = @('/a', "`"$Path`"", '/qn', "TARGETDIR=`"$DestinationPath\\SourceDir`"")
    }

    $LogPath = Split-Path $Path -Parent | Join-Path -ChildPath 'msi.log'
    if ($Switches) { $ArgList += (-split $Switches) }

    $Status = Invoke-ExternalCommand $MsiPath $ArgList -LogPath $LogPath
    if (!$Status) {
        # TODO: Stop-ScoopExecution
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }

    $sourceDir = Join-Path $DestinationPath 'SourceDir'
    if ($ExtractDir -and (Test-Path $sourceDir)) {
        movedir (Join-Path $sourceDir $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    } elseif ($ExtractDir) {
        movedir (Join-Path $DestinationPath $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    } elseif (Test-Path $sourceDir) {
        movedir $sourceDir $DestinationPath | Out-Null
    }

    $fnamePath = Join-Path $DestinationPath (fname $Path)
    if (($DestinationPath -ne (Split-Path $Path)) -and (Test-Path $fnamePath)) { Remove-Item $fnamePath -Force }
    if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
    # Remove original archive file
    if ($Removal) { Remove-Item $Path -Force }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Parameter(ValueFromRemainingArguments)]
        [String] $Switches,
        [Switch] $Removal
    )

    $LogPath =  Split-Path $Path -Parent | Join-Path -ChildPath 'innounp.log'
    $ArgList = @('-x', "-d`"$DestinationPath`"", "`"$Path`"", '-y')
    switch -Regex ($ExtractDir) {
        '^[^{].*' { $ArgList += "-c{app}\$ExtractDir" }
        '^{.*' { $ArgList += "-c$ExtractDir" }
        default { $ArgList += '-c{app}' }
    }
    if ($Switches) { $ArgList += (-split $Switches) }

    try {
        $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Innounp) $ArgList -LogPath $LogPath
    } catch [System.Management.Automation.ParameterBindingException] {
        Write-UserMessage -Message '''innounp'' is not installed or cannot be used' -Err
    }
    if (!$Status) {
        # TODO: Stop-ScoopExecution: throw
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
    # Remove original archive file
    if ($Removal) { Remove-Item $Path -Force }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [String] $DestinationPath = (Split-Path $Path),
        [String] $ExtractDir,
        [Switch] $Removal
    )

    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = Join-Path $DestinationPath '_tmp'
    }

    # All methods to unzip the file require .NET4.5+
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
        } catch [System.IO.PathTooLongException] {
            # try to fall back to 7zip if path is too long
            if (Test-HelperInstalled -Helper 7zip) {
                Expand-7zipArchive $Path $DestinationPath -Removal:$Removal
                return
            } else {
                # TODO: Stop-ScoopExecution: throw
                abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch [System.IO.IOException] {
            if (Test-HelperInstalled -Helper 7zip) {
                Expand-7zipArchive $Path $DestinationPath -Removal:$Removal
                return
            } else {
                # TODO: Stop-ScoopExecution: throw
                abort "Unzip failed: Windows can't handle the file names in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch {
            # TODO: Stop-ScoopExecution: throw
            abort "Unzip failed: $_"
        }
    } else {
        # Use Expand-Archive to unzip in PowerShell 5+
        # Compatible with Pscx (https://github.com/Pscx/Pscx)
        Microsoft.PowerShell.Archive\Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
    }
    if ($ExtractDir) {
        movedir (Join-Path $DestinationPath $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    }
    # Remove original archive file
    if ($Removal) { Remove-Item $Path -Force }
}

function Expand-DarkArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Path,
        [Parameter(Position = 1)]
        [String] $DestinationPath = (Split-Path $Path),
        [Parameter(ValueFromRemainingArguments = $true)]
        [String] $Switches,
        [Switch] $Removal
    )

    $LogPath = Split-Path $Path -Parent | Join-Path -ChildPath 'dark.log'
    $ArgList = @('-nologo', "-x `"$DestinationPath`"", "`"$Path`"")
    if ($Switches) { $ArgList += (-split $Switches) }

    try {
        $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Dark) $ArgList -LogPath $LogPath
    } catch [System.Management.Automation.ParameterBindingException] {
        Write-UserMessage -Message '''dark'' is not installed or cannot be used' -Err
    }
    if (!$Status) {
        # TODO: Stop-ScoopExecution: throw
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
    # Remove original archive file
    if ($Removal) { Remove-Item $Path -Force }
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
