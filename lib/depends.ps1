'Helpers', 'install', 'decompress' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}


# Resolve dependencies for the supplied apps, and sort into the correct order
function install_order($apps, $arch) {
    $res = @()
    foreach ($app in $apps) {
        $deps = @()
        try {
            $deps = deps $app $arch
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            continue
        }

        foreach ($dep in $deps) {
            if ($res -notcontains $dep) { $res += $dep }
        }
        if ($res -notcontains $app) { $res += $app }
    }

    return $res
}

# http://www.electricmonk.nl/docs/dependency_resolving_algorithm/dependency_resolving_algorithm.html
function deps($app, $arch) {
    $resolved = New-Object System.Collections.ArrayList
    dep_resolve $app $arch $resolved @()

    if ($resolved.Count -eq 1) { return @() } # No dependencies

    return $resolved[0..($resolved.Count - 2)]
}

function dep_resolve($app, $arch, $resolved, $unresolved) {
    #[out]$resolved
    #[out]$unresolved

    $app, $bucket, $null = parse_app $app
    $unresolved += $app
    $null, $manifest, $null, $null = Find-Manifest $app $bucket

    if (!$manifest) {
        if ($bucket -and ((Get-LocalBucket) -notcontains $bucket)) {
            Write-UserMessage -Message "Bucket '$bucket' not installed. Add it with 'scoop bucket add $bucket' or 'scoop bucket add $bucket <repo>'." -Warning
        }

        throw [ScoopException] "Could not find manifest for '$app'$(if(!$bucket) { '.' } else { " from '$bucket' bucket." })" # TerminatingError thrown
    }

    $deps = @(install_deps $manifest $arch) + @(runtime_deps $manifest) | Select-Object -Unique

    foreach ($dep in $deps) {
        if ($resolved -notcontains $dep) {
            if ($unresolved -contains $dep) {
                throw [ScoopException] "Circular dependency detected: '$app' -> '$dep'." # TerminatingError thrown
            }
            dep_resolve $dep $arch $resolved $unresolved
        }
    }
    $resolved.Add($app) | Out-Null
    $unresolved = $unresolved -ne $app # Remove from unresolved
}

function runtime_deps($manifest) {
    if ($manifest.depends) { return $manifest.depends }
}

function script_deps($script) {
    $deps = @()
    if ($script -is [Array]) { $script = $script -join "`n" }

    if ([String]::IsNullOrEmpty($script)) { return $deps }

    if (($script -like '*Expand-DarkArchive *') -and !(Test-HelperInstalled -Helper 'Dark')) { $deps += 'dark' }
    if (($script -like '*Expand-7zipArchive *') -and !(Test-HelperInstalled -Helper '7zip')) { $deps += '7zip' }
    if (($script -like '*Expand-MsiArchive *') -and !(Test-HelperInstalled -Helper 'Lessmsi')) { $deps += 'lessmsi' }
    if ($script -like '*Expand-InnoArchive *') {
        if ((get_config 'INNOSETUP_USE_INNOEXTRACT' $false) -or ($script -like '* -UseInnoextract *')) {
            if (!(Test-HelperInstalled -Helper 'InnoExtract')) { $deps += 'innoextract' }
        } else {
            if (!(Test-HelperInstalled -Helper 'Innounp')) { $deps += 'innounp' }
        }
    }
    if (($script -like '*Expand-ZstdArchive *') -and !(Test-HelperInstaller -Helper 'Zstd')) {
        # Ugly, unacceptable and horrible patch to cover the tar.zstd use cases
        if (!(Test-HelperInstalled -Helper '7zip')) { $deps += '7zip' }
        $deps += 'zstd'
    }

    return $deps
}

function install_deps($manifest, $arch) {
    $deps = @()
    $urls = url $manifest $arch

    if ((Test-7zipRequirement -URL $urls) -and !(Test-HelperInstalled -Helper '7zip')) { $deps += '7zip' }
    if ((Test-LessmsiRequirement -URL $urls) -and !(Test-HelperInstalled -Helper 'Lessmsi')) { $deps += 'lessmsi' }
    if ($manifest.innosetup) {
        if (get_config 'INNOSETUP_USE_INNOEXTRACT' $false) {
            if (!(Test-HelperInstalled -Helper 'Innoextract')) { $deps += 'innoextract' }
        } else {
            if (!(Test-HelperInstalled -Helper 'Innounp')) { $deps += 'innounp' }
        }
    }
    if ((Test-ZstdRequirement -URL $urls) -and !(Test-HelperInstalled -Helper 'Zstd')) {
        # Ugly, unacceptable and horrible patch to cover the tar.zstd use cases
        if (!(Test-HelperInstalled -Helper '7zip')) { $deps += '7zip' }
        $deps += 'zstd'
    }

    $pre_install = arch_specific 'pre_install' $manifest $arch
    $installer = arch_specific 'installer' $manifest $arch
    $post_install = arch_specific 'post_install' $manifest $arch

    $deps += script_deps $pre_install
    $deps += script_deps $installer.script
    $deps += script_deps $post_install

    return $deps | Select-Object -Unique
}
