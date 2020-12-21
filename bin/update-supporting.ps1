<#
.SYNOPSIS
    Update supporting tools to the latest version.
.PARAMETER Supporting
    Specifies the name of supporting tool to be updated.
#>
param([String] $Supporting = '*', [Switch] $Install)

$ErrorActionPreference = 'Stop'
$checkver = Join-Path $PSScriptRoot 'checkver.ps1'
$Sups = Join-Path $PSScriptRoot '..\supporting\*' | Get-ChildItem -Include "$Supporting.*" -File

'decompress', 'Helpers', 'manifest', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

foreach ($sup in $Sups) {
    $name = $sup.BaseName
    $folder = $sup.Directory
    $dir = Join-Path $folder "$name\bin"

    Write-UserMessage -Message "Updating $name" -Color 'Magenta'

    & "$checkver" -App "$name" -Dir "$folder" -Update

    if (!$Install) { continue }

    try {
        $manifest = ConvertFrom-Manifest -Path $sup.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($sup.Name)" -Err
        continue
    }

    Remove-Module 'powershell-yaml'
    Start-Sleep -Seconds 2

    Rename-Item $dir 'old' -ErrorAction 'SilentlyContinue'
    Confirm-DirectoryExistence $dir | Out-Null
    Start-Sleep -Seconds 2

    $fname = dl_urls $name $manifest.version $manifest '' (default_architecture) $dir $true $true
    $fname | Out-Null
    # Pre install is enough now
    pre_install $manifest $architecture

    Write-UserMessage -Message "$name done" -Success

    Join-Path $folder "$name\old" | Remove-Item -Force -Recurse
}
