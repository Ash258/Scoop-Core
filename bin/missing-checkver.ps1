<#
.SYNOPSIS
    Check if manifest contains checkver and autoupdate property.
.PARAMETER App
    Specifies the manifest name.
    Wirldcards are supported.
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
Write-Host 'C' -NoNewline -ForegroundColor 'Green'
Write-Host ']heckver'
Write-Host ' | [' -NoNewline
Write-Host 'A' -NoNewline -ForegroundColor 'Cyan'
Write-Host ']utoupdate'
Write-Host ' |  |'

foreach ($file in Get-ChildItem $Dir "$App.*" -File) {
    try {
        $json = ConvertFrom-Manifest -Path $file.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($file.Name)" -Err
        continue
    }

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -ForegroundColor 'Green' -NoNewline
    Write-Host ']' -NoNewline

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -ForegroundColor 'Cyan' -NoNewline
    Write-Host '] ' -NoNewline
    Write-Host $file.BaseName
}
