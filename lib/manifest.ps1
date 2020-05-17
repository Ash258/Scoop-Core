'core', 'autoupdate', 'buckets' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

function manifest_path($app, $bucket) {
    fullpath "$(Find-BucketDirectory $bucket)\$(sanitary_path $app).json"
}

function parse_json($path) {
    if (!(Test-Path $path)) { return $null }

    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
}

function url_manifest($url) {
    $str = $null
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $str = $wc.downloadstring($url)
    } catch [system.management.automation.methodinvocationexception] {
        # TODO: ???
        Write-UserMessage -Message "error: $($_.Exception.InnerException.Message)" -Warning
    } catch {
        throw
    }
    if (!$str) { return $null }

    return $str | ConvertFrom-Json
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }
    parse_json (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if ($url) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        # TODO: YML
        $wc.downloadstring($url) | Out-UTF8File "$dir\scoop-manifest.json"
    } else {
        # TODO: YML
        Copy-Item (manifest_path $app $bucket) "$dir\scoop-manifest.json"
    }
}

function installed_manifest($app, $version, $global) {
    # TODO: YML
    $old = 'manifest.json'
    $new = 'scoop-manifest.json'
    $d = versiondir $app $version $global
    # Migration
    if (Test-Path "$d\$old") {
        Write-UserMessage -Message "Migrating $old to $new" -Info
        Rename-Item "$d\$old" $new
    }
    return parse_json "$d\$new"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    $info | ConvertToPrettyJson | Out-UTF8File "$dir\scoop-install.json"
}

function install_info($app, $version, $global) {
    $d = versiondir $app $version $global
    $path = "$d\scoop-install.json"

    if (!(Test-Path $path)) {
        if (Test-Path "$d\install.json") {
            Write-UserMessage -Message "Migrating install.json to scoop-install.json" -Info
            Rename-Item "$d\install.json" 'scoop-install.json'
        } else {
            return $null
        }
    }

    return parse_json $path
}

function default_architecture {
    $arch = get_config 'default-architecture'
    $system = if ([Environment]::Is64BitOperatingSystem) { '64bit' } else { '32bit' }
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
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }
    Write-UserMessage -Warning -Message @(
        "Given version ($version) does not match manifest ($($manifest.version))"
        "Attempting to generate manifest for '$app' ($version)"
    )

    if (!($manifest.autoupdate)) {
        abort "'$app' does not have autoupdate capability`r`ncouldn't find manifest for '$app@$version'"
    }

    ensure $(usermanifestsdir) | Out-Null
    try {
        autoupdate $app "$(Resolve-Path $(usermanifestsdir))" $manifest $version $(@{ })
        return "$(Resolve-Path $(usermanifest $app))"
    } catch {
        Write-Host -f darkred "Could not install $app@$version"
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
