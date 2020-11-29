'core', 'Helpers', 'autoupdate', 'buckets' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function manifest_path($app, $bucket) {
    $name = sanitary_path $app

    # TODO: YAML
    return Find-BucketDirectory $bucket | Join-Path -ChildPath "$name.json"
}

function parse_json {
    param([Parameter(Mandatory, ValueFromPipeline)] [System.IO.FileInfo] $Path)

    process {
        if (!(Test-Path $Path)) { return $null }

        return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    }
}

function url_manifest($url) {
    $str = $null
    try {
        $wc = New-Object System.Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $str = $wc.DownloadString($url)
    } catch [System.Management.Automation.MethodInvocationException] {
        Write-UserMessage -Message "${url}: $($_.Exception.InnerException.Message)" -Warning
    } catch {
        throw $_.Exception.Message
    }
    if (!$str) { return $null }

    return $str | ConvertFrom-Json
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }

    return parse_json (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if ($url) {
        $wc = New-Object System.Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        # TODO: YML
        Join-Path $dir 'scoop-manifest.json' | Out-UTF8Content -Content ($wc.DownloadString($url))
    } else {
        # TODO: YML
        Copy-Item (manifest_path $app $bucket) (Join-Path $dir 'scoop-manifest.json')
    }
}

function installed_manifest($app, $version, $global) {
    # TODO: YML
    $old = 'manifest.json'
    $new = 'scoop-manifest.json'
    $d = versiondir $app $version $global

    # Migration
    if (Join-Path $d $old | Test-Path ) {
        Write-UserMessage -Message "Migrating $old to $new" -Info
        Join-Path $d $old | Rename-Item -NewName $new
    }

    return parse_json (Join-Path $d $new)
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    $info | ConvertToPrettyJson | Out-UTF8File -Path (Join-Path $dir 'scoop-install.json')
}

# TODO: Deprecate
function install_info($app, $version, $global) {
    $d = versiondir $app $version $global
    $path = Join-Path $d 'scoop-install.json'

    if (!(Test-Path $path)) {
        if (Join-Path $d 'install.json' | Test-Path) {
            Write-UserMessage -Message 'Migrating install.json to scoop-install.json' -Info
            Join-Path $d 'install.json' | Rename-Item -NewName 'scoop-install.json'
        } else {
            return $null
        }
    }

    return parse_json $path
}

function default_architecture {
    $arch = get_config 'default-architecture'
    $system = if ([System.IntPtr]::Size -eq 8) { '64bit' } else { '32bit' }

    if ($null -eq $arch) {
        $arch = $system
    } else {
        try {
            $arch = ensure_architecture $arch
        } catch {
            Write-UserMessage -Message 'Invalid default architecture configured. Determining default system architecture' -Warning
            $arch = $system
        }
    }

    return $arch
}

function arch_specific($prop, $manifest, $architecture) {
    if ($manifest.architecture) {
        $val = $manifest.architecture.$architecture.$prop
        if ($val) { return $val } # else fallback to generic prop
    }

    if ($manifest.$prop) { return $manifest.$prop }
}

function supports_architecture($manifest, $architecture) {
    return -not [String]::IsNullOrEmpty((arch_specific 'url' $manifest $architecture))
}

function generate_user_manifest($app, $bucket, $version) {
    $null, $manifest, $bucket, $null = Find-Manifest $app $bucket

    if ($manifest.version -eq $version) { return manifest_path $app $bucket }

    Write-UserMessage -Warning -Message @(
        "Given version ($version) does not match manifest ($($manifest.version))"
        "Attempting to generate manifest for '$app' ($version)"
    )

    if (!($manifest.autoupdate)) {
        Write-UserMessage -Message "'$app' does not have autoupdate capability`r`ncouldn't find manifest for '$app@$version'" -Warning
        return $null
    }

    $path = usermanifestsdir | ensure
    try {
        Invoke-Autoupdate $app "$path" $manifest $version $(@{ })

        return (usermanifest $app | Resolve-Path).Path
    } catch {
        throw "Could not install $app@$version"
    }

    return $null
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function msi($manifest, $arch) { arch_specific 'msi' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }
function extract_dir($manifest, $arch) { arch_specific 'extract_dir' $manifest $arch }
function extract_to($manifest, $arch) { arch_specific 'extract_to' $manifest $arch }
