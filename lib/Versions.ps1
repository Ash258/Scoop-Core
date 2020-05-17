'core', 'manifest' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

function Get-LatestVersion {
    <#
    .SYNOPSIS
        Gets the latest version of app from manifest.
    .PARAMETER AppName
        Specifies application's name.
    .PARAMETER Bucket
        Specifies bucket which the app belongs to.
    .PARAMETER Uri
        Specifies remote app manifest's URI.
    #>
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('App')]
        [String] $AppName,
        [Parameter(Position = 1)]
        [String] $Bucket,
        [Parameter(Position = 2)]
        [String] $Uri
    )

    process { return (manifest $AppName $Bucket $Uri).version }
}

function Get-InstalledVersion {
    <#
    .SYNOPSIS
        Gets all installed version of app, by checking version directories' 'scoop-install.json'
    .PARAMETER AppName
        Specifies application's name.
    .PARAMETER Global
        Specifies globally installed application.
    .NOTES
        Versions are sorted from oldest to newest, i.e., latest installed version is the last one in the output array.
        If no installed version found, empty array will be returned.
    #>
    [OutputType([Object[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('App')]
        [String] $AppName,
        [Parameter(Position = 1)]
        [Switch] $Global
    )

    process {
        $appPath = appdir $AppName $Global
        $result = @()

        if (Test-Path $appPath -PathType Container) {
            # TODO: Keep only scoop-install.json
            $arr = @((Get-ChildItem "$appPath\*\install.json"), (Get-ChildItem "$appPath\*\scoop-install.json"))
            $versions = @(($arr | Sort-Object -Property LastWriteTimeUtc).Directory.Name)
            $result = $versions | Where-Object { $_ -ne 'current' } | Where-Object { $_ -notlike '_*.old*' }
        }

        return $result
    }
}

function Select-CurrentVersion {
    <#
    .SYNOPSIS
        Select current version of installed app, from 'current\manifest.json' or modified time of version directory
    .PARAMETER AppName
        Specifies application's name.
    .PARAMETER Global
        Specifies globally installed application.
    #>
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [Alias('App')]
        [String] $AppName,
        [Parameter(Position = 1)]
        [Switch] $Global
    )

    process {
        $appPath = appdir $AppName $Global

        if (Test-Path "$appPath\current" -PathType Container) {
            $currentVersion = (installed_manifest $AppName 'current' $Global).version
            # Get version from link target in case of nightly
            if ($currentVersion -eq 'nightly') { $currentVersion = ((Get-Item "$appPath\current").Target | Get-Item).BaseName }
        } else {
            $installedVersion = @(Get-InstalledVersion -AppName $AppName -Global:$Global)
            $currentVersion = if ($installedVersion) { $installedVersion[-1] } else { $null }
        }

        return $currentVersion
    }
}

function Compare-Version {
    <#
    .SYNOPSIS
        Compares versions, mainly according to SemVer's rules.
    .PARAMETER ReferenceVersion
        Specifies a version used as a reference for comparison.
    .PARAMETER DifferenceVersion
        Specifies the version that are compared to the reference version.
    .PARAMETER Delimiter
        Specifies the delimiter of versions.
    .OUTPUTS
        System.Int32
            '0' if DifferenceVersion is equal to ReferenceVersion,
            '1' if DifferenceVersion is greater then ReferenceVersion,
            '-1' if DifferenceVersion is less then ReferenceVersion
    #>
    [OutputType([Int])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [Alias('Old')]
        [String] $ReferenceVersion,
        [Parameter(Position = 1, ValueFromPipeline)]
        [Alias('New')]
        [AllowEmptyString()]
        [String] $DifferenceVersion,
        [String] $Delimiter = '-'
    )

    process {
        # Use '+' sign as post-release, see https://github.com/lukesampson/scoop/pull/3721#issuecomment-553718093
        $ReferenceVersion, $DifferenceVersion = @($ReferenceVersion, $DifferenceVersion) -replace '\+', '-'

        # Return 0 if versions are strictly equal
        if ($DifferenceVersion -eq $ReferenceVersion) { return 0 }

        # Preprocess versions (split, convert and separate)
        $splitReferenceVersion = @(Split-Version -Version $ReferenceVersion -Delimiter $Delimiter)
        $splitDifferenceVersion = @(Split-Version -Version $DifferenceVersion -Delimiter $Delimiter)

        # Nightly versions are always equal
        if (($splitReferenceVersion[0] -eq 'nightly') -and ($splitDifferenceVersion[0] -eq 'nightly')) { return 0 }

        for ($i = 0; $i -lt [Math]::Max($splitReferenceVersion.Length, $splitDifferenceVersion.Length); $i++) {
            # '1.1-alpha' is less then '1.1'
            if ($i -ge $splitReferenceVersion.Length) {
                if ($splitDifferenceVersion[$i] -match 'alpha|beta|rc|pre') {
                    return -1
                } else {
                    return 1
                }
            }
            # '1.1' is greater then '1.1-beta'
            if ($i -ge $splitDifferenceVersion.Length) {
                if ($splitReferenceVersion[$i] -match 'alpha|beta|rc|pre') {
                    return 1
                } else {
                    return -1
                }
            }

            # If some parts of versions have '.', compare them with delimiter '.'
            if (($splitReferenceVersion[$i] -match '\.') -or ($splitDifferenceVersion[$i] -match '\.')) {
                $Result = Compare-Version -ReferenceVersion $splitReferenceVersion[$i] -DifferenceVersion $splitDifferenceVersion[$i] -Delimiter '.'
                # If the parts are equal, continue to next part, otherwise return
                if ($Result -ne 0) {
                    return $Result
                } else {
                    continue
                }
            }

            # Don't try to compare [Long] to [String]
            if (($null -ne $splitReferenceVersion[$i]) -and ($null -ne $splitDifferenceVersion[$i])) {
                if (($splitReferenceVersion[$i] -is [String]) -and ($splitDifferenceVersion[$i] -isnot [String])) {
                    $splitDifferenceVersion[$i] = "$($splitDifferenceVersion[$i])"
                }
                if (($splitDifferenceVersion[$i] -is [String]) -and ($splitReferenceVersion[$i] -isnot [String])) {
                    $splitReferenceVersion[$i] = "$($splitReferenceVersion[$i])"
                }
            }

            # Compare [String] or [Long]
            if ($splitDifferenceVersion[$i] -gt $splitReferenceVersion[$i]) { return 1 }
            if ($splitDifferenceVersion[$i] -lt $splitReferenceVersion[$i]) { return -1 }
        }
    }
}

function Split-Version {
    <#
    .SYNOPSIS
        Splits version by Delimiter, convert number string to number, and separate letters from numbers.
    .PARAMETER Version
        Specifies a version to be splitted.
    .PARAMETER Delimiter
        Specifies the delimiter of version (Literal).
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Version,
        [String] $Delimiter = '-'
    )

    process {
        $Version = $Version -replace '[a-zA-Z]+', "$Delimiter$&$Delimiter"

        return ($Version -split [Regex]::Escape($Delimiter) -ne '' | ForEach-Object { if ($_ -match '^\d+$') { [Long] $_ } else { $_ } })
    }

}

#region Deprecated
function qsort($ary, $fn) {
    Write-UserMessage -Message '"qsort" is deprecated. Please avoid using it anymore.' -Warning

    if ($null -eq $ary) { return @() }
    if (!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length - 1)]

    $lesser = qsort ($rem | Where-Object { (& $fn $pivot $_) -lt 0 }) $fn

    $greater = qsort ($rem | Where-Object { (& $fn $pivot $_) -ge 0 }) $fn

    return @() + $lesser + @($pivot) + $greater
}

function sort_versions($versions) {
    Write-UserMessage -Message '"sort_versions" is deprecated. Please avoid using it anymore.' -Warning
    return qsort $versions Compare-Version
}

function compare_versions($a, $b) {
    Show-DeprecatedWarning $MyInvocation 'Compare-Version'
    return Compare-Version -ReferenceVersion $b -DifferenceVersion $a
}

function latest_version($app, $bucket, $url) {
    Show-DeprecatedWarning $MyInvocation 'Get-LatestVersion'
    return Get-LatestVersion -AppName $app -Bucket $bucket -Uri $url
}

function current_version($app, $global) {
    Show-DeprecatedWarning $MyInvocation 'Select-CurrentVersion'
    return Select-CurrentVersion -AppName $app -Global:$global
}

function versions($app, $global) {
    Show-DeprecatedWarning $MyInvocation 'Get-InstalledVersion'
    return Get-InstalledVersion -AppName $app -Global:$global
}
#endregion Deprecated
