<#
.SYNOPSIS
    Search for application description on homepage.
.PARAMETER App
    Specifies the manifest name.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
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

'core', 'Helpers', 'manifest', 'description' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir
$exitCode = 0
$problems = 0
$Queue = @()

foreach ($m in Get-ChildItem $Dir "$App.*" -File) {
    try {
        $manifest = ConvertFrom-Manifest -Path $m.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($m.Name)" -Err
        ++$problems
        continue
    }
    $Queue += , @($m.BaseName, $manifest)
}

foreach ($qq in $Queue) {
    $name, $manifest = $qq
    Write-Host "${name}: " -NoNewline

    if (!$manifest.homepage) {
        Write-UserMessage -Message "`nNo homepage set." -Err
        ++$problems
        continue
    }
    # Get description from homepage
    try {
        $wc = New-Object System.Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.DownloadString($manifest.homepage)
    } catch {
        Write-UserMessage -Message "`n$($_.Exception.Message)" -Err
        ++$problems
        continue
    }

    $description, $descr_method = find_description $manifest.homepage $home_html
    if (!$description) {
        Write-UserMessage -Message "`nDescription not found ($($manifest.homepage))" -Color 'Red'
        ++$problems
        continue
    }

    $description = clean_description $description

    Write-UserMessage -Message "(found by $descr_method)"
    Write-UserMessage -Message "  ""$description""" -Color 'Green'
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
