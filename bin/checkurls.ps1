<#
.SYNOPSIS
    List manifests which do not have valid URLs.
.PARAMETER App
    Manifest name to search.
    Wildcards is supported.
.PARAMETER Dir
    Where to search for manifest(s).
.PARAMETER Timeout
    How long (seconds) the request can be pending before it times out.
.PARAMETER SkipValid
    Manifests will all valid URLs will not be shown.
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
    [Int] $Timeout = 5,
    [Switch] $SkipValid
)

'core', 'manifest', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Timeout | Out-Null # PowerShell/PSScriptAnalyzer#1472

$Dir = Resolve-Path $Dir
$Queue = @()

Get-ChildItem $Dir "$App.*" -File | ForEach-Object {
    $manifest = parse_json $_.FullName
    $Queue += , @($_.Name, $manifest)
}

Write-Host '[' -NoNewLine
Write-Host 'U' -NoNewLine -ForegroundColor Cyan
Write-Host ']RLs'
Write-Host ' | [' -NoNewLine
Write-Host 'O' -NoNewLine -ForegroundColor Green
Write-Host ']kay'
Write-Host ' |  | [' -NoNewLine
Write-Host 'F' -NoNewLine -ForegroundColor Red
Write-Host ']ailed'
Write-Host ' |  |  |'

function test_dl([String] $url, $cookies) {
    # Trim renaming suffix, prevent getting 40x response
    $url = ($url -split '#/')[0]

    $wreq = [System.Net.WebRequest]::Create($url)
    $wreq.Timeout = $Timeout * 1000
    if ($wreq -is [System.Net.HttpWebRequest]) {
        $wreq.UserAgent = Get-UserAgent
        $wreq.Referer = strip_filename $url
        if ($cookies) {
            $wreq.Headers.Add('Cookie', (cookie_header $cookies))
        }
    }
    $wres = $null
    try {
        $wres = $wreq.GetResponse()

        return $url, $wres.StatusCode, $null
    } catch {
        $e = $_.Exception
        if ($e.InnerException) { $e = $e.InnerException }

        return $url, 'Error', $e.Message
    } finally {
        if ($null -ne $wres -and $wres -isnot [System.Net.FtpWebResponse]) {
            $wres.Close()
        }
    }
}

foreach ($man in $Queue) {
    $name, $manifest = $man
    $urls = @()
    $ok = 0
    $failed = 0
    $errors = @()

    if ($manifest.url) {
        $manifest.url | ForEach-Object { $urls += $_ }
    } else {
        url $manifest '64bit' | ForEach-Object { $urls += $_ }
        url $manifest '32bit' | ForEach-Object { $urls += $_ }
    }

    $urls | ForEach-Object {
        $url, $status, $msg = test_dl $_ $manifest.cookie
        if ($msg) { $errors += "$msg ($url)" }
        if ($status -eq 'OK' -or $status -eq 'OpeningData') { $ok += 1 } else { $failed += 1 }
    }

    if (($ok -eq $urls.Length) -and $SkipValid) { continue }

    # URLS
    Write-Host '[' -NoNewLine
    Write-Host $urls.Length -NoNewLine -ForegroundColor Cyan
    Write-Host ']' -NoNewLine

    # Okay
    $okColor = 'Yellow'
    if ($ok -eq $urls.Length) {
        $okColor = 'Green'
    } elseif ($ok -eq 0) {
        $okColor = 'Red'
    }
    Write-Host '[' -NoNewLine
    Write-Host $ok -ForegroundColor $okColor -NoNewLine
    Write-Host ']' -NoNewLine

    # Failed
    $fColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
    Write-Host '[' -NoNewLine
    Write-Host $failed -ForegroundColor $fColor -NoNewline
    Write-Host '] ' -NoNewLine
    Write-Host (strip_ext $name)

    $errors | ForEach-Object {
        Write-Host "       > $_" -ForegroundColor DarkRed
    }
}
