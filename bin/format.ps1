<#
.SYNOPSIS
    Format manifest.
.PARAMETER App
    Specifies the manifest name.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
.EXAMPLE
    PS BUCKETROOT> .\bin\format.ps1
    Format all manifests inside bucket directory.
.EXAMPLE
    PS BUCKETROOT> .\bin\format.ps1 7zip
    Format manifest '7zip' inside bucket directory.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir
)

'core', 'Helpers', 'manifest', 'json' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir
$exitCode = 0
$problems = 0

function _infoMes ($name, $mes) { Write-UserMessage -Message "${name}: $mes" -Info }

function _adjustProperty ($Manifest, $Property, $ScriptBlock, [Switch] $SkipAutoupdate, [Switch] $SkipArchitecture) {
    $prop = $Manifest.$Property
    if ($prop) {
        $Manifest.$Property = $ScriptBlock.Invoke($prop)[0]
    }

    # Architecture specific
    $archSpec = $Manifest.architecture
    if (!$SkipArchitecture -and $archSpec) {
        (Get-NotePropertyEnumerator -Object $archSpec).Name | ForEach-Object {
            if ($archSpec.$_ -and $archSpec.$_.$Property) {
                $Manifest.architecture.$_.$Property = $ScriptBlock.Invoke($archSpec.$_.$Property)
            }
        }

    }

    if (!$SkipAutoupdate -and $Manifest.autoupdate) {
        $Manifest.autoupdate = _adjustProperty -Manifest $Manifest.autoupdate -Property $Property -ScriptBlock $ScriptBlock -SkipAutoupdate
    }

    return $Manifest
}

#region Formatters
$checkverFormatBlock = {
    $checkver = $Manifest.checkver
    if ($checkver -and ($checkver.GetType() -ne [System.String])) {
        # Remove not needed url
        if ($checkver.url -and ($checkver.url -eq $Manifest.homepage)) {
            _infoMes $name 'Removing checkver.url (same as homepage)'
            $checkver.PSObject.Properties.Remove('url')
        }

        if ($checkver.jp) {
            _infoMes $name 'checkver.jp -> checkver.jsonpath'

            $checkver | Add-Member -MemberType 'NoteProperty' -Name 'jsonpath' -Value $checkver.jp
            $checkver.PSObject.Properties.Remove('jp')
        }

        if ($checkver.re) {
            _infoMes $name 'checkver.re -> checkver.regex'

            $checkver | Add-Member -MemberType 'NoteProperty' -Name 'regex' -Value $checkver.re
            $checkver.PSObject.Properties.Remove('re')

            if ($checkver.reverse) {
                _infoMes $name 'checkver.reverse -> after regex'

                $rev = $checkver.reverse
                $checkver.PSObject.Properties.Remove('reverse')
                $checkver | Add-Member -MemberType 'NoteProperty' -Name 'reverse' -Value $rev
            }
        }

        # Only one property regex
        if (($checkver.PSObject.Properties.Name.Count -eq 1) -and $checkver.regex) {
            _infoMes $name 'alone checkver.regex -> checkver'
            $checkver = $checkver.regex
        }

        if (($checkver.PSObject.Properties.Name -eq 'replace') -and ($checkver.PSObject.Properties.Name[-1] -ne 'replace')) {
            _infoMes $name 'Sort: checkver.replace -> latest'

            $repl = $checkver.replace
            $checkver.PSObject.Properties.Remove('replace')
            $checkver | Add-Member -MemberType 'NoteProperty' -Name 'replace' -Value $repl
        }

        # Only one github property and homepage is set to github repository
        if (($checkver.PSObject.Properties.Name.Count -eq 1) -and $checkver.github -and ($checkver.github -eq $Manifest.homepage)) {
            _infoMes $name 'alone checkver.github -> checkver github string'

            $checkver = 'github'
        }
    }

    return $checkver
}
#endregion Formatters

foreach ($gci in Get-ChildItem $Dir "$App.*" -File) {
    $name = $gci.Basename
    if ($gci.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $($gci.Name)" -Info
        continue
    }

    try {
        $manifest = ConvertFrom-Manifest -Path $gci.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($gci.Name)" -Err
        ++$problems
        continue
    }

    #region Migrations and fixes
    # Migrate _comment into ##
    if ($manifest.'_comment') {
        $manifest | Add-Member -MemberType 'NoteProperty' -Name '##' -Value $manifest.'_comment'
        $manifest.PSObject.Properties.Remove('_comment')
    }

    $manifest = _adjustProperty -Manifest $manifest -Property 'checkver' -ScriptBlock $checkverFormatBlock -SkipAutoupdate

    #region Architecture properties sort
    # TODO: Extract
    foreach ($mainProp in 'architecture', 'autoupdate') {
        if ($mainProp -eq 'autoupdate') {
            if ($manifest.$mainProp.architecture) {
                $arch = $manifest.$mainProp.architecture
            } else {
                continue
            }
        } else {
            if ($manifest.$mainProp) {
                $arch = $manifest.$mainProp
            } else {
                continue
            }
        }

        # Skip single architecture
        if ($arch.PSObject.Properties.Name.Count -eq 1) { continue }

        $newArch = [PSCustomObject] @{ }

        # TODO: Mulitple architectures
        '64bit', '32bit' | ForEach-Object {
            if ($arch.$_) { $newArch | Add-Member -MemberType 'NoteProperty' -Name $_ -Value $arch.$_ }
        }

        if ($arch.PSObject.Properties.Name[0] -ne '64bit') {
            _infoMes $name "Sorting Arch: $mainProp"
            $arch = $newArch
        }

        if ($mainProp -eq 'autoupdate') {
            $manifest.$mainProp.architecture = $newArch
        } else {
            $manifest.$mainProp = $newArch
        }
    }
    #endregion Architecture properties sort

    $newManifest = [PSCustomObject] @{ }
    # Add informational properties in special order ranked by usability into new object and remove from old object
    # Comment for maintainers has to be at first
    # Version is mandatory manifest identificator
    # Description is mandatory and essential information for user
    # Homepage provides additional information in case description is not enough
    # License has to follow immediatelly after homepage. User most likely decided to install app after reading description or visiting homepage
    # Notes contains useful information for user. When they cat the manifest it has to be visible on top
    # Changelog is additional not required information
    '##', 'version', 'description', 'homepage', 'license', 'notes', 'changelog', 'suggest', 'depends' | ForEach-Object {
        $val = $manifest.$_
        if ($val) {
            $newManifest | Add-Member -MemberType 'NoteProperty' -Name $_ -Value $val
            $manifest.PSObject.Properties.Remove($_)
        }
    }

    # Add remaining properties in same order
    $manifest.PSObject.Properties.Name | ForEach-Object {
        $newManifest | Add-Member -MemberType 'NoteProperty' -Name $_ -Value $manifest.$_
    }

    $manifest = $newManifest
    #endregion Migrations and fixes

    ConvertTo-Manifest -Path $gci.FullName -Manifest $manifest
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
