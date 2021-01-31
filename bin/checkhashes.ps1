<#
.SYNOPSIS
    Check if all urls defined in manifest have correct hashes.
.PARAMETER App
    Specifies the manifest name to be checked (without extension).
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
.PARAMETER Update
    Specifies to update the manifest file with updated hashes.
.PARAMETER ForceUpdate
    Specifies to update the manifest file even without hashes were not changed.
.PARAMETER SkipCorrect
    Specifies to not show manifest without mismatched hashes.
.PARAMETER UseCache
    Specifies to not delete downloaded files from cache.
    Should not be used, because check should be used for downloading actual version of file (as normal user, not finding in some document from vendors, which could be damaged / wrong (Example: Slack@3.3.1 lukesampson/scoop-extras#1192)), not some previously downloaded.
.EXAMPLE
    PS BUCKETROOT> .\bin\checkhashes.ps1
    Check all manifests for hash mismatch.
.EXAMPLE
    PS BUCKETROOT> .\bin\checkhashes.ps1 MANIFEST -Update
    Check MANIFEST and Update if there are some wrong hashes.
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
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipCorrect,
    [Alias('k')]
    [Switch] $UseCache
)

'core', 'Helpers', 'manifest', 'buckets', 'autoupdate', 'json', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir
if ($ForceUpdate) { $Update = $true }
$exitCode = 0
$problems = 0
# Cleanup
if (!$UseCache) { Join-Path $SCOOP_CACHE_DIRECTORY '*HASH_CHECK*' | Remove-Item -ErrorAction 'SilentlyContinue' -Force -Recurse }

function err ([String] $name, [String[]] $message) {
    Write-UserMessage "${name}: ", ($message -join "`r`n") -Color 'Red'
}

$MANIFESTS = @()
# Gather all required manifests
foreach ($gci in Get-ChildItem $Dir "$App.*" -File) {
    if ($gci.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $($gci.Name)" -Info
        continue
    }

    $name = $gci.BaseName
    try {
        $manifest = ConvertFrom-Manifest -Path $gci.FullName
    } catch {
        err $name 'Invalid manifest'
        ++$problems
        continue
    }

    # Skip nighly manifests, since their hash validation is skipped
    if ($manifest.version -eq 'nightly') { continue }

    $urls = @()
    $hashes = @()

    if ($manifest.url) {
        $manifest.url | ForEach-Object { $urls += $_ }
        $manifest.hash | ForEach-Object { $hashes += $_ }
    } elseif ($manifest.architecture) {
        # First handle 64bit
        # TODO: Multiple architectures
        url $manifest '64bit' | ForEach-Object { $urls += $_ }
        hash $manifest '64bit' | ForEach-Object { $hashes += $_ }
        url $manifest '32bit' | ForEach-Object { $urls += $_ }
        hash $manifest '32bit' | ForEach-Object { $hashes += $_ }
    } else {
        err $name 'Manifest does not contain URL property.'
        ++$problems
        continue
    }

    # Number of URLS and Hashes is different
    if ($urls.Length -ne $hashes.Length) {
        err $name 'URLS and hashes count mismatch.'
        ++$problems
        continue
    }

    $MANIFESTS += @{
        'app'      = $name
        'manifest' = $manifest
        'urls'     = $urls
        'hashes'   = $hashes
        'gci'      = $gci
    }
}

foreach ($current in $MANIFESTS) {
    $count = 0
    # Array of indexes mismatched hashes.
    $mismatched = @()
    # Array of computed hashes
    $actuals = @()

    $break = $false
    foreach ($u in $current.urls) {
        $algorithm, $expected = get_hash $current.hashes[$count]
        $version = 'HASH_CHECK'
        try {
            dl_with_cache $current.app $version $u $null $null -use_cache:$UseCache
        } catch {
            $break = $true
            continue
        }

        $to_check = cache_path $current.app $version $u
        $actual_hash = compute_hash $to_check $algorithm

        # Append type of algorithm to both expected and actual if it's not sha256
        if ($algorithm -ne 'sha256') {
            $actual_hash = "${algorithm}:$actual_hash"
            $expected = "${algorithm}:$expected"
        }

        $actuals += $actual_hash
        if ($actual_hash -ne $expected) { $mismatched += $count }
        ++$count
    }

    if ($break) {
        err $current.app 'Download failed'
        ++$problems
        continue
    }

    if ($mismatched.Length -eq 0 ) {
        if (!$SkipCorrect) {
            Write-Host "$($current.app): " -NoNewline
            Write-Host 'OK' -ForegroundColor 'Green'
        }
    } else {
        Write-Host "$($current.app): " -NoNewline
        Write-Host 'Mismatch found ' -ForegroundColor 'Red'
        $mismatched | ForEach-Object {
            $file = cache_path $current.app $version $current.urls[$_]
            # TODO: Wrap into function
            Write-UserMessage -Message "`tURL:`t`t$($current.urls[$_])"
            if (Test-Path $file) {
                Write-UserMessage -Message "`tFirst bytes:`t$(Get-MagicByte -File $file -Pretty)"
            }
            Write-UserMessage -Message "`tExpected:`t$($current.hashes[$_])" -Color 'Green'
            Write-UserMessage -Message "`tActual:`t`t$($actuals[$_])" -Color 'Red'
        }
    }

    if ($Update) {
        if ($current.manifest.url -and $current.manifest.hash) {
            $current.manifest.hash = $actuals
        } else {
            $platforms = ($current.manifest.architecture | Get-Member -MemberType 'NoteProperty').Name
            # TODO: Multiple architectures
            # Defaults to zero, don't know, which architecture is available
            $64bit_count = 0
            $32bit_count = 0

            if ($platforms.Contains('64bit')) {
                $64bit_count = $current.manifest.architecture.'64bit'.hash.Count
                # 64bit is get, donwloaded and added first
                $current.manifest.architecture.'64bit'.hash = $actuals[0..($64bit_count - 1)]
            }
            if ($platforms.Contains('32bit')) {
                $32bit_count = $current.manifest.architecture.'32bit'.hash.Count
                $max = $64bit_count + $32bit_count - 1 # Edge case if manifest contains 64bit and 32bit.
                $current.manifest.architecture.'32bit'.hash = $actuals[($64bit_count)..$max]
            }
        }

        Write-UserMessage -Message "Writing updated $($current.app) manifest" -Color 'DarkGreen'

        ConvertTo-Manifest -Path $current.gci.FullName -Manifest $current.manifest
    } else {
        # Consider error only if manifest was not updated
        if ($mismatched.Count -gt 0) { ++$problems }
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode
