'core', 'Helpers', 'autoupdate', 'buckets', 'json' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

Join-Path $PSScriptRoot '..\supporting\yaml\bin\powershell-yaml.psd1' | Import-Module -Prefix 'CloudBase' -Verbose:$false

$ALLOWED_MANIFEST_EXTENSION = @('json', 'yaml', 'yml')
$ALLOWED_MANIFEST_EXTENSION_REGEX = $ALLOWED_MANIFEST_EXTENSION -join '|'

function ConvertFrom-Manifest {
    <#
    .SYNOPSIS
        Parse manifest file into object.
    .PARAMETER Path
        Specifies the path to the file representing manifest.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('LiteralPath', 'File')]
        [System.IO.FileInfo] $Path
    )

    process {
        if (!(Test-Path $Path -PathType 'Leaf')) { return $null }

        $result = $null
        $content = Get-Content $Path -Encoding 'UTF8' -Raw

        switch ($Path.Extension) {
            '.json' {
                $result = ConvertFrom-Json -InputObject $content -ErrorAction 'Stop'
            }
            { $_ -in '.yaml', '.yml' } {
                # Ugly hotfix to prevent ordering of properties and PSCustomObject
                $result = ConvertFrom-CloudBaseYaml -Yaml $content -Ordered | ConvertTo-Json -Depth 100 | ConvertFrom-Json
            }
            default {
                Write-UserMessage -Message "Not specific manifest extension ($_). Falling back to json" -Info
                $result = ConvertFrom-Json -InputObject $content -ErrorAction 'Stop'
            }
        }

        return $result
    }
}

function ConvertTo-Manifest {
    <#
    .SYNOPSIS
        Convert manifest object into string.
    .PARAMETER File
        Specifies the path to the file where manifest will be saved.
    .PARAMETER Manifest
        Specifies the manifest object.
    .PARAMETER Extension
        Specifies the structure of resulted string (json, yaml, yml)
        Ignored if File is provided.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Path', 'LiteralPath')]
        [System.IO.FileInfo] $File,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('InputObject', 'Content')]
        $Manifest,
        [Parameter(ValueFromPipelineByPropertyName)]
        [String] $Extension
    )

    process {
        $ext = if ($File) { $File.Extension.TrimStart('.') } else { $Extension }
        $content = $null

        switch ($ext) {
            'json' {
                $content = $Manifest | ConvertToPrettyJson
                $content = $content -replace "`t", (' ' * 4)
            }
            { $_ -in 'yaml', 'yml' } {
                $content = ConvertTo-CloudBaseYaml -Data $Manifest
            }
            default {
                Write-UserMessage -Message "Not specific manifest extension ($_). Falling back to json" -Info
                $content = $Manifest | ConvertToPrettyJson
                $content = $content -replace "`t", (' ' * 4)
            }
        }

        if ($File) {
            Out-UTF8File -File $File.FullName -Content $content
        } else {
            return $content
        }
    }
}

function manifest_path($app, $bucket) {
    $name = sanitary_path $app
    $buc = Find-BucketDirectory -Bucket $bucket
    $file = Get-ChildItem -LiteralPath $buc -Filter "$name.*"
    $path = $null

    if ($file) {
        if ($file.Count -gt 1) { $file = $file[0] }
        $path = $file.FullName
    }

    return $path
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

    # TODO: YAML
    return $str | ConvertFrom-Json
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }

    $path = manifest_path $app $bucket
    try {
        $manifest = ConvertFrom-Manifest -Path $path
    } catch {
        $manifest = $null
    }

    return $manifest
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
    $d = versiondir $app $version $global

    #region Migration from non-generic file name
    $old = 'manifest.json'
    $new = 'scoop-manifest.json'
    if (Join-Path $d $old | Test-Path) {
        Write-UserMessage -Message "Migrating $old to $new" -Info
        Join-Path $d $old | Rename-Item -NewName $new
    }
    $manifestPath = Join-Path $d $new
    #endregion Migration from non-generic file name

    # Different extension types
    if (!(Test-Path $manifestPath)) {
        $installedManifests = Get-ChildItem -LiteralPath $d -Include 'scoop-manifest.*'
        if ($installedManifests.Count -gt 0) {
            $manifestPath = $installedManifests[0].FullName
        }
    }

    return ConvertFrom-Manifest -Path $manifestPath
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

function Invoke-ManifestScript {
    <#
    .SYNOPSIS
        Execute script properties defined in manifest.
    .PARAMETER Manifest
        Specifies the manifest object.
    .PARAMETER ScriptName
        Specifies the property name.
    .PARAMETER Architecture
        Specifies the architecture.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [Alias('InputObject')]
        $Manifest,
        [Parameter(Mandatory)]
        [String] $ScriptName,
        [String] $Architecture
    )

    process {
        $script = arch_specific $ScriptName $Manifest $Architecture
        if ($script) {
            $print = $ScriptName -replace '_', '-'
            Write-UserMessage -Message "Running $print script..." -Output:$false
            Invoke-Expression (@($script) -join "`r`n")
        }
    }
}

function generate_user_manifest($app, $bucket, $version) {
    $cleanApp, $manifest, $bucket, $null = Find-Manifest $app $bucket

    if ($manifest.version -eq $version) { return manifest_path $app $bucket }

    Write-UserMessage -Warning -Message "Looking for archived manifest for '$app' ($version)"

    # Seach local path
    # TODO: Export to function
    $archivedManifest = Find-BucketDirectory -Name $bucket | Join-Path -ChildPath "old\$cleanApp" | Get-ChildItem -ErrorAction 'SilentlyContinue' -File
    $archivedManifest = $archivedManifest | Where-Object -Property 'Name' -Match -Value "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)$"
    if ($archivedManifest.Count -gt 0) {
        $archivedManifest = @($archivedManifest | Where-Object -Property 'BaseName' -EQ -Value $version)
        $archivedManifest = $archivedManifest[0]
    }

    if ($archivedManifest -and (Test-Path -LiteralPath $archivedManifest)) {
        $archivedManifest = Get-Item -LiteralPath $archivedManifest
        Write-UserMessage -Message 'Found archived version' -Success

        $workspace = usermanifestsdir | Join-Path -ChildPath "$cleanApp$($archivedManifest.Extension)"
        Copy-Item $archivedManifest.FullName $workspace -Force

        return $workspace
    }

    Write-UserMessage -Warning -Message @(
        "Given version ($version) does not match manifest ($($manifest.version))"
        "Attempting to generate manifest for '$app' ($version)"
    )

    if (!($manifest.autoupdate)) {
        Write-UserMessage -Warning -Message @(
            "'$app' does not have autoupdate capability"
            "could not find manifest for '$app@$version'"
        )
        return $null
    }

    $path = usermanifestsdir | ensure
    try {
        $newManifest = Invoke-Autoupdate $app "$path" $manifest $version $(@{ }) -IgnoreArchive
        if ($null -eq $newManifest) { throw "Could not install $app@$version" }

        Write-UserMessage -Message "Writing updated $app manifest" -Color 'DarkGreen'
        ConvertTo-Manifest -Path (Join-Path $path "$app.json") -Manifest $newManifest

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
