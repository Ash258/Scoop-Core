<#
.SYNOPSIS
    List manifests which do not have valid URLs.
.PARAMETER App
    Specifies the manifest name to search.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
.PARAMETER Timeout
    Specifies how long (seconds) the request can be pending before it times out.
.PARAMETER SkipValid
    Specifies to not show manifests, which have all URLs valid.
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
    [Int] $Timeout = 5,
    [Switch] $SkipValid
)

'core', 'manifest', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Timeout | Out-Null # PowerShell/PSScriptAnalyzer#1472
$Dir = Resolve-Path $Dir
$Queue = @()
$exitCode = 0
$problems = 0

foreach ($gci in Get-ChildItem $Dir "$App.*" -File) {
    if ($gci.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $($gci.Name)" -Info
        continue
    }

    try {
        $manifest = ConvertFrom-Manifest -Path $gci.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($gci.Name)" -Err
        continue
    }
    $Queue += , @($gci.BaseName, $manifest)
}

Write-Host '[' -NoNewline
Write-Host 'U' -ForegroundColor 'Cyan' -NoNewline
Write-Host ']RLs'
Write-Host ' | [' -NoNewline
Write-Host 'O' -ForegroundColor 'Green' -NoNewline
Write-Host ']kay'
Write-Host ' |  | [' -NoNewline
Write-Host 'F' -ForegroundColor 'Red' -NoNewline
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
    $errors = @()
    $urls = @()
    $ok = 0
    $failed = 0

    if ($manifest.url) {
        $manifest.url | ForEach-Object { $urls += $_ }
    } else {
        # TODO: Multiple architectures
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
    Write-Host '[' -NoNewline
    Write-Host $urls.Length -ForegroundColor 'Cyan' -NoNewline
    Write-Host ']' -NoNewline

    # Okay
    $okColor = 'Yellow'
    if ($ok -eq $urls.Length) {
        $okColor = 'Green'
    } elseif ($ok -eq 0) {
        $okColor = 'Red'
    }
    Write-Host '[' -NoNewline
    Write-Host $ok -ForegroundColor $okColor -NoNewline
    Write-Host ']' -NoNewline

    # Failed
    $fColor = if ($failed -eq 0) { 'Green' } else { 'Red' }
    Write-Host '[' -NoNewline
    Write-Host $failed -ForegroundColor $fColor -NoNewline
    Write-Host '] ' -NoNewline
    Write-Host $name

    $errors | ForEach-Object {
        Write-Host "       > $_" -ForegroundColor 'DarkRed'
    }

    if ($failed.Count -gt 0) { ++$problems }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
