<#
.SYNOPSIS
    Format manifest.
.PARAMETER App
    Manifest to format.
.PARAMETER Dir
    Where to search for manifest(s).
.EXAMPLE
    PS BUCKETROOT> .\bin\formatjson.ps1
    Format all manifests inside bucket directory.
.EXAMPLE
    PS BUCKETROOT> .\bin\formatjson.ps1 7zip
    Format manifest '7zip' inside bucket directory.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) { throw "$_ is not a directory!" }
        $true
    })]
    [String] $Dir
)

'core', 'Helpers', 'manifest', 'json' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir

function _infoMes ($name, $mes) { Write-UserMessage -Message "${name}: $mes" -Info }

foreach ($m in Get-ChildItem $Dir "$App.*" -File) {
    $path = $m.Fullname

    if ($m.Extension -notin '.json', '.yml', '.yaml') { continue }

    $manifest = parse_json $path
    $name = $m.Basename

    #region Migrations and fixes
    # Checkver
    $checkver = $manifest.checkver
    if ($checkver -and ($checkver.GetType() -ne [System.String])) {
        # Remove not needed url
        if ($checkver.url -and ($checkver.url -eq $manifest.homepage)) {
            _infoMes $name 'Removing checkver.url (same as homepage)'
            $checkver.PSObject.Properties.Remove('url')
        }

        if ($checkver.jp) {
            _infoMes $name 'checkver.jp -> checkver.jsonpath'

            $checkver | Add-Member -MemberType NoteProperty -Name 'jsonpath' -Value $checkver.jp
            $checkver.PSObject.Properties.Remove('jp')
        }

        if ($checkver.re) {
            _infoMes $name 'checkver.re -> checkver.regex'

            $checkver | Add-Member -MemberType NoteProperty -Name 'regex' -Value $checkver.re
            $checkver.PSObject.Properties.Remove('re')

            if ($checkver.reverse) {
                _infoMes $name 'checkver.reverse -> after regex'

                $rev = $checkver.reverse
                $checkver.PSObject.Properties.Remove('reverse')
                $checkver | Add-Member -MemberType NoteProperty -Name 'reverse' -Value $rev
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
            $checkver | Add-Member -MemberType NoteProperty -Name 'replace' -Value $repl
        }

        # Only one github property and homepage is set to github repository
        if (($checkver.PSObject.Properties.Name.Count -eq 1) -and $checkver.github -and ($checkver.github -eq $manifest.homepage)) {
            _infoMes $name 'alone checkver.github -> checkver github string'

            $checkver = 'github'
        }

        $manifest.checkver = $checkver
    }

    # Architecture properties sort
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

        '64bit', '32bit' | ForEach-Object {
            if ($arch.$_) { $newArch | Add-Member -MemberType NoteProperty -Name $_ -Value $arch.$_ }
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

    $newManifest = [PSCustomObject] @{ }
    '##', '_comment', 'version', 'description', 'homepage', 'license', 'notes', 'depends' | ForEach-Object {
        if ($manifest.$_) {
            $newManifest | Add-Member -MemberType NoteProperty -Name $_ -Value $manifest.$_
            $manifest.PSObject.Properties.Remove($_)
        }
    }

    # Add remaining properties in same order
    $manifest.PSObject.Properties.Name | ForEach-Object {
        $newManifest | Add-Member -MemberType NoteProperty -Name $_ -Value $manifest.$_
    }

    $manifest = $newManifest
    #endregion Migrations and fixes

    ($manifest | ConvertToPrettyJson) -replace "`t", (' ' * 4) | Out-UTF8File -File $path
}
