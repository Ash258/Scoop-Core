<#
.SYNOPSIS
    Update supporting tools to the latest version.
.PARAMETER Supporting
    Specifies the name of supporting tool to be updated.
#>
param([String] $Supporting = '*')

'decompress', 'Helpers', 'manifest', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Sups = Join-Path $PSScriptRoot '..\supporting\*' | Get-ChildItem -Include "$Supporting.*" -File

foreach ($sup in $Sups) {
    $name = $sup.BaseName
    $folder = $sup.Directory
    $dir = Join-Path $folder "$name\bin"

    Write-UserMessage -Message "Updating $name" -Color 'Magenta'

    $checkver = Join-Path $PSScriptRoot 'checkver.ps1'
    & "$checkver" -App "$name" -Dir "$folder" -Update

    try {
        $manifest = ConvertFrom-Manifest -Path $sup.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($sup.Name)" -Err
        continue
    }
    Confirm-DirectoryExistence $dir | Out-Null

    $fname = dl_urls $name $manifest.version $manifest '' default_architecture $dir $true $true
    $fname | Out-Null
    # Pre install is enough now
    pre_install $manifest $architecture

    Write-UserMessage -Message "$name done" -Success
}
