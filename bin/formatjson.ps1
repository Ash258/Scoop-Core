<#
.SYNOPSIS
    Format manifest.
.PARAMETER App
    Specifies the manifest name.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
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
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir
)

Write-Host 'WARN  Binary ''formatjson'' is deprecated and will be removed in near future. Use ''format'' instead'
& (Join-Path $PSScriptRoot 'format.ps1') -App $App -Dir $Dir

exit $LASTEXITCODE
