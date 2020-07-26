<#
.SYNOPSIS
    Check if manifest contains checkver and autoupdate property.
.PARAMETER App
    Manifest name.
    Wirldcards are supported.
.PARAMETER Dir
    Location of manifests.
.PARAMETER SkipSupported
    Manifests with checkver and autoupdate will not be presented.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory = $true)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) { throw "$_ is not a directory!" }
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

Write-Host '[' -NoNewLine
Write-Host 'C' -NoNewLine -ForegroundColor Green
Write-Host ']heckver'
Write-Host ' | [' -NoNewLine
Write-Host 'A' -NoNewLine -ForegroundColor Cyan
Write-Host ']utoupdate'
Write-Host ' |  |'

Get-ChildItem $Dir "$App.*" -File | ForEach-Object {
    $json = parse_json $_.FullName

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewLine
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -NoNewLine -ForegroundColor Green
    Write-Host ']' -NoNewLine

    Write-Host '[' -NoNewLine
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -NoNewLine -ForegroundColor Cyan
    Write-Host '] ' -NoNewLine
    Write-Host (strip_ext $_.Name)
}
