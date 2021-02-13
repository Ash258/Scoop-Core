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

$exitCode = 0
$problems = 0
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
        ++$problems
        continue
    }

    Remove-Module 'powershell-yaml' -ErrorAction 'SilentlyContinue' -Force
    Start-Sleep -Seconds 2

    Rename-Item $dir 'old' -ErrorAction 'SilentlyContinue'
    Confirm-DirectoryExistence -Directory $dir | Out-Null
    Start-Sleep -Seconds 2
    try {
        $fname = dl_urls $name $manifest.version $manifest '' (default_architecture) $dir $true $true
        $fname | Out-Null
        # Pre install is enough now
        Invoke-ManifestScript -Manifest $manifest -ScriptName 'pre_install' -Architecture $architecture
    } catch {
        ++$problems

        $title, $body = $_.Exception.Message -split '\|-'
        if (!$body) { $body = $title }
        Write-UserMessage -Message $body -Err
        debug $_.InvocationInfo

        continue
    }

    Write-UserMessage -Message "$name done" -Success

    Join-Path $folder "$name\old" | Remove-Item -Force -Recurse
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
