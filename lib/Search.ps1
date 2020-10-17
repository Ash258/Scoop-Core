'core', 'buckets', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

function Search-LocalBucket {
    <#
    .SYNOPSIS
        Search all manifests in locally added bucket.
    .DESCRIPTION
        Descriptions, binaries and shortcuts will be used for searching.
    .PARAMETER Bucket
        Specifies the bucket name to be searched in.
    .PARAMETER Query
        Specifies the regular expression to be used for searching.
    .OUTPUTS [System.Object[]]
        Array of all result hashtables with bucket and results properties.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Bucket,
        [AllowNull()]
        [String] $Query
    )

    begin {
        $architecture = default_architecture
        $apps = @()
        $result = @()
    }

    process {
        foreach ($app in apps_in_bucket (Find-BucketDirectory -Name $Bucket)) {
            $manifest = manifest $app $Bucket
            $apps += @{
                'name'              = $app
                'version'           = $manifest.version
                'description'       = $manifest.description
                'shortcuts'         = @(arch_specific 'shortcuts' $manifest $arch)
                'matchingShortcuts' = @()
                'bin'               = @(arch_specific 'bin' $manifest $arch)
                'matchingBinaries'  = @()
            }
        }

        if (!$Query) { return $apps }

        foreach ($a in $apps) {
            # Manifest name matching
            if (($a.name -match $Query) -and (!$result -contains $a)) { $result += $a }

            # Binary matching
            $a.bin | ForEach-Object {
                $executable, $shimName, $argument = shim_def $_
                if ($shimName -match $Query) {
                    $bin = @{ 'exe' = $executable; 'name' = $shimName }
                    if ($result -contains $a) {
                        $result[$result.IndexOf($a)].matchingBinaries += $bin
                    } else {
                        $a.matchingBinaries += $bin
                        $result += $a
                    }
                }
            }

            # Shortcut matching
            foreach ($shortcut in $a.shortcuts) {
                # Is this necessary?
                if (($shortcut -is [Array]) -and ($shortcut.Length -ge 2)) {
                    $executable = $shortcut[0]
                    $name = $shortcut[1]

                    if (($name -match $Query) -or ($executable -match $Query)) {
                        $short = @{ 'exe' = $executable; 'name' = $name }
                        if ($result -contains $a) {
                            $result[$result.IndexOf($a)].matchingShortcuts += $short
                        } else {
                            $a.matchingShortcuts += $short
                            $result += $a
                        }
                    }
                }
            }
        }
    }

    end { return $result }
}

function Search-AllRemote {
    <#
    .SYNOPSIS
        Search all remote buckets using GitHub API.
    .DESCRIPTION
        Remote search happens only in buckets, which are not added locally and only manifest name is taken into account.
    .PARAMETER Query
        Specifies the regular expression to be searched in remote.
    .OUTPUTS [System.Object[]]
        Array of all result hashtables with bucket and results properties.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param([String] $Query)

    process {
        $Query | Out-Null # PowerShell/PSScriptAnalyzer#1472
        $results = Get-KnownBucket | Where-Object { !(Find-BucketDirectory $_ | Test-Path) } | ForEach-Object {
            @{
                'bucket'  = $_
                'results' = (search_remote $_ $Query)
            }
        } | Where-Object { $_.results }

        return @($results)
    }
}
