<#
.SYNOPSIS
    Check if manifest contains checkver and autoupdate property.
.PARAMETER App
    Specifies the manifest name.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
.PARAMETER SkipSupported
    Specifies to not show manifests with checkver and autoupdate properties.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir,
    [Switch] $SkipSupported
)

'core', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$SkipSupported | Out-Null # PowerShell/PSScriptAnalyzer#1472

$Dir = Resolve-Path $Dir

Write-Host '[' -NoNewline
Write-Host 'C' -ForegroundColor 'Green' -NoNewline
Write-Host ']heckver'
Write-Host ' | [' -NoNewline
Write-Host 'A' -ForegroundColor 'Cyan' -NoNewline
Write-Host ']utoupdate'
Write-Host ' |  |'

Get-ChildItem $Dir "$App.*" -File | ForEach-Object {
    $json = parse_json $_.FullName

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -ForegroundColor 'Green' -NoNewline
    Write-Host ']' -NoNewline

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -ForegroundColor 'Cyan' -NoNewline
    Write-Host '] ' -NoNewline
    Write-Host $_.BaseName
}
