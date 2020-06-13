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
    . "$PSScriptRoot\..\lib\$_.ps1"
}

$Dir = Resolve-Path $Dir

foreach ($m in Get-ChildItem $Dir "$App.*") {
    $path = $m.Fullname

    # beautify
    $manifest = parse_json $path

    # Some migrations and fixes
    Write-UserMessage $m.Basename

    # Checkver
    $checkver = $manifest.checkver
    if ($checkver) {
        # Remove not needed url
        if ($checkver.url -and ($checkver.url -eq $manifest.homepage)) {
            Write-UserMessage -Message 'Removing checkver.url (same as homepage)' -Info
            $checkver.PSObject.Properties.Remove('url')
        }

        if ($checkver.re) {
            Write-UserMessage -Message 'checkver.re -> checkver.regex' -Info

            $checkver | Add-Member -MemberType NoteProperty -Name 'regex' -Value $checkver.re
            $checkver.PSObject.Properties.Remove('re')
        }

        if ($checkver.jp) {
            Write-UserMessage -Message 'checkver.jp -> checkver.jsonpath' -Info

            $checkver | Add-Member -MemberType NoteProperty -Name 'jsonpath' -Value $checkver.jp
            $checkver.PSObject.Properties.Remove('jp')
        }

        # Only one property regex
        if (($checkver.PSObject.Properties.name.Count -eq 1) -and $checkver.regex) {
            Write-UserMessage -Message 'alone checkver.regex -> checkver' -Info
            $checkver = $checkver.regex
        }

        $manifest.checkver = $checkver
    }

    # Property Sort

    # $manifest
    $manifest = $manifest | ConvertToPrettyJson

    # Convert to 4 spaces
    $manifest -replace "`t", (' ' * 4) | Out-UTF8File -File $path
}
