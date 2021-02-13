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

'core', 'Helpers', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$SkipSupported | Out-Null # PowerShell/PSScriptAnalyzer#1472
$Dir = Resolve-Path $Dir
$exitCode = 0
$problems = 0

Write-Host '[' -NoNewline
Write-Host 'C' -ForegroundColor 'Green' -NoNewline
Write-Host ']heckver'
Write-Host ' | [' -NoNewline
Write-Host 'A' -ForegroundColor 'Cyan' -NoNewline
Write-Host ']utoupdate'
Write-Host ' |  |'

foreach ($gci in Get-ChildItem $Dir "$App.*" -File) {
    if ($gci.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $($gci.Name)" -Info
        continue
    }

    try {
        $json = ConvertFrom-Manifest -Path $gci.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($gci.Name)" -Err
        ++$problems
        continue
    }

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -ForegroundColor 'Green' -NoNewline
    Write-Host ']' -NoNewline

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -ForegroundColor 'Cyan' -NoNewline
    Write-Host '] ' -NoNewline
    Write-Host $gci.BaseName
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
