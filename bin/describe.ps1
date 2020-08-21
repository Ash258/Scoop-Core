<#
.SYNOPSIS
    Search for application description on homepage.
.PARAMETER App
    Manifest name to search.
    Wildcards are supported.
.PARAMETER Dir
    Where to search for manifest(s).
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) { throw "$_ is not a directory!" }
        $true
    })]
    [String] $Dir
)

'core', 'Helpers', 'manifest', 'description' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir
$Queue = @()

Get-ChildItem $Dir "$App.*" -File | ForEach-Object {
    $manifest = parse_json $_.FullName
    $Queue += , @($_.BaseName, $manifest)
}

$Queue | ForEach-Object {
    $name, $manifest = $_
    Write-Host "${name}: " -NoNewline

    if (!$manifest.homepage) {
        Write-UserMessage -Message "`nNo homepage set." -Err
        return
    }
    # get description from homepage
    try {
        $wc = New-Object System.Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.DownloadString($manifest.homepage)
    } catch {
        Write-UserMessage -Message "`n$($_.Exception.Message)" -Err
        return
    }

    $description, $descr_method = find_description $manifest.homepage $home_html
    if (!$description) {
        Write-UserMessage -Message "`nDescription not found ($($manifest.homepage))" -Color Red
        return
    }

    $description = clean_description $description

    Write-UserMessage -Message "(found by $descr_method)"
    Write-UserMessage -Message "  ""$description""" -Color Green
}
