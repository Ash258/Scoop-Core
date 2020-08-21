<#
.SYNOPSIS
    Update supporting tools to the latest version.
.PARAMETER Supporting
    Name of supporting tool to be updated.
#>
param([String] $Supporting = '*')

'decompress', 'Helpers', 'manifest', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Sups = Join-Path $PSScriptRoot '..\supporting\*' | Get-ChildItem -File -Include "$Supporting.*"

foreach ($sup in $Sups) {
    $name = $sup.BaseName
    $folder = $sup.Directory
    $dir = Join-Path $folder "$name\bin"

    Write-UserMessage -Message "Updating $name" -Color Magenta

    $checkver = Join-Path $PSScriptRoot 'checkver.ps1'
    Invoke-Expression "& $checkver -App $name -Dir $folder -Update"

    $manifest = parse_json $sup.FullName
    ensure $dir | Out-Null

    dl_urls $name $manifest.version $manifest '' default_architecture $dir $true $true | Out-Null
    # Pre install is enough now
    pre_install $manifest $architecture

    Write-UserMessage -Message "$name done" -Success
}
