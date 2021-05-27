
. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Manifests operations' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = (setup_working 'manifest' | Resolve-Path).Path
        Move-Item "$working_dir\*.*" "$working_dir\bucket"
        $SCOOP_BUCKETS_DIRECTORY = $working_dir | Split-Path

        Copy-Item $working_dir "$SCOOP_BUCKETS_DIRECTORY\ash258.ash258" -Force -Recurse
        Copy-Item $working_dir "$SCOOP_BUCKETS_DIRECTORY\main" -Force -Recurse
    }

    It 'manifest_path' {
        $path = manifest_path 'cosi' 'manifest'
        $path | Should -Be "$working_dir\bucket\cosi.yaml"
        $path = $null

        $path = manifest_path 'wget' 'manifest'
        $path | Should -Be "$working_dir\bucket\wget.json"
        $path = $null

        $path = manifest_path 'pwsh' 'ash258.ash258'
        $path | Should -Be "$SCOOP_BUCKETS_DIRECTORY\ash258.ash258\bucket\pwsh.json"
        $path = $null

        $path = manifest_path 'cosi' 'main'
        $path | Should -Be "$SCOOP_BUCKETS_DIRECTORY\main\bucket\cosi.yaml"
        $path = $null

        $path = manifest_path 'pwsh' 'alfa'
        $path | Should -Be $null
        $path = $null

        $path = manifest_path 'ahoj' 'main'
        $path | Should -Be $null
        $path = $null
    }

    It 'manifest_path with version' {
        $path = manifest_path 'cosi' 'main' '7.1.0'
        $path | Should -Be "$SCOOP_BUCKETS_DIRECTORY\main\bucket\old\cosi\7.1.0.yaml"
        $path = $null

        $path = manifest_path 'pwsh' 'ash258.ash258' '6.2.3'
        $path | Should -Be "$SCOOP_BUCKETS_DIRECTORY\ash258.ash258\bucket\old\pwsh\6.2.3.yml"
        $path = $null

        $path = manifest_path 'pwsh' 'ash258.ash258' '2222'
        $path | Should -Be $null
        $path = $null

        { manifest_path 'wget' 'ash258.ash258' '2222' } | Should -Throw 'Bucket ''ash258.ash258'' does not contain archived version ''2222'' for ''wget'''
        $path = $null
    }

    It 'New-VersionedManifest' {
        $path = manifest_path 'pwsh' 'ash258.ash258'
        $new = New-VersionedManifest -LiteralPath $path -Version '7.1.0' 6>$null
        $new | Should -BeLike "$env:SCOOP\manifests\pwsh-*.json"
        (ConvertFrom-Manifest -LiteralPath $new).version | Should -Be '7.1.0'
        $path = $null

        $path = manifest_path 'cosi' 'main'
        $new = New-VersionedManifest -LiteralPath $path -Version '6.2.3' 6>$null
        $new | Should -BeLike "$env:SCOOP\manifests\cosi-*.yaml"
        (ConvertFrom-Manifest -LiteralPath $new).version | Should -Be '6.2.3'
        $path = $null

        { manifest_path 'cosi' 'main' | New-VersionedManifest -Version '22222' 6>$null } | Should -Throw 'Cannot generate manifest with version ''22222'''

        $path = manifest_path 'broken_wget' 'main'
        { New-VersionedManifest -LiteralPat $path -Version '22222' 6>$null } | Should -Throw "Invalid manifest '$path'"
        $path = $null
    }

    Describe 'Resolve-ManifestInformation' {
        Describe 'Get-LocalManifest' {
            It 'Full path' {
                $result = Resolve-ManifestInformation "$working_dir\bucket\pwsh.json"
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.checkver | Should -Be 'github'
                $result.LocalPath | Should -Be "$working_dir\bucket\pwsh.json"
                $result = $null

                # Mix of dividers
                $result = Resolve-ManifestInformation "$working_dir\bucket/cosi.yaml"
                $result.ApplicationName | Should -Be 'cosi'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.checkver | Should -Be 'github'
                $result.LocalPath | Should -Be "$working_dir\bucket\cosi.yaml"
                $result = $null
            }

            It 'Full versioned path' {
                $result = Resolve-ManifestInformation "$working_dir\bucket\old\pwsh\6.2.3.yml"
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '6.2.3'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.LocalPath | Should -Be "$working_dir\bucket\old\pwsh\6.2.3.yml"
                $result = $null

                $result = Resolve-ManifestInformation "$working_dir\bucket\old\cosi\7.1.0.yaml"
                $result.ApplicationName | Should -Be 'cosi'
                $result.Version | Should -Be '7.1.0'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.LocalPath | Should -Be "$working_dir\bucket\old\cosi\7.1.0.yaml"
                $result = $null

                $result = Resolve-ManifestInformation "$working_dir\bucket/old\cosi/7.1.0.yaml"
                $result.ApplicationName | Should -Be 'cosi'
                $result.Version | Should -Be '7.1.0'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.LocalPath | Should -Be "$working_dir\bucket\old\cosi\7.1.0.yaml"
                $result = $null

                $result = Resolve-ManifestInformation "$($working_dir -replace '\\', '/')/bucket/old/cosi/7.1.0.yaml"
                $result.ApplicationName | Should -Be 'cosi'
                $result.Version | Should -Be '7.1.0'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result = $null
            }

            It 'Error handling' {
                { manifest_path 'invalid_wget' 'main' | Resolve-ManifestInformation } | Should -Throw 'Not a valid manifest'
                ( { manifest_path 'broken_wget' 'main' | Resolve-ManifestInformation } | Should -Throw -Passthru).Exception.Message | Should -BeLike 'File is not a valid manifest*'
            }
        }

        Describe 'Get-RemoteManifest' {
            # TODO: Mockup to not download the file

            It 'Direct manifest URL' {
                $result = Resolve-ManifestInformation 'https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/068225b07cad6baeb46eb1adc26f8207fa423508/bucket/aaaaa.json'
                $result.ApplicationName | Should -Be 'aaaaa'
                $result.Version | Should -Be '0.0.15-12154'
                $result.ManifestObject.checkver.github | Should -Be 'https://github.com/RPCS3/rpcs3-binaries-win'
                $result = $null

                $result = Resolve-ManifestInformation 'https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/184d2f072798441e8eb03a655dea16f2695ee699/bucket/alfa.yaml'
                $result.ApplicationName | Should -Be 'alfa'
                $result.Version | Should -Be '0.0.15-12154'
                $result.ManifestObject.checkver.github | Should -Be 'https://github.com/RPCS3/rpcs3-binaries-win'
                $result = $null
            }

            It 'Versioned manifest URL' {
                $result = Resolve-ManifestInformation 'https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/068225b07cad6baeb46eb1adc26f8207fa423508/bucket/old/alfa/0.0.15-12060.yaml'
                $result.ApplicationName | Should -Be 'alfa'
                $result.Version | Should -Be '0.0.15-12060'
                $result.ManifestObject.bin | Should -Be 'rpcs3.exe'
                $result = $null

                $result = Resolve-ManifestInformation 'https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/8117ddcbadc606f5d4576778676e81bfc6dc2e78/bucket/old/aaaaa/0.0.15-11936.json'
                $result.ApplicationName | Should -Be 'aaaaa'
                $result.Version | Should -Be '0.0.15-11936'
                $result.ManifestObject.bin | Should -Be 'rpcs3.exe'
                $result = $null
            }

            It 'Downloaded manifest load' {
                $result = Resolve-ManifestInformation 'https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/184d2f072798441e8eb03a655dea16f2695ee699/bucket/alfa.yaml'
                $result.ApplicationName | Should -Be 'alfa'
                $result.Version | Should -Be '0.0.15-12154'
                $result.ManifestObject.checkver.github | Should -Be 'https://github.com/RPCS3/rpcs3-binaries-win'

                $resultNew = Resolve-manifestInformation $result.LocalPath
                $resultNew.ApplicationName | Should -Be 'alfa'
                $resultNew.LocalPath.Basename | Should -BeLike 'alfa-258258--*'
                $resultNew.Version | Should -Be '0.0.15-12154'
                $result = $resultNew = $null
            }
        }

        Describe 'Get-ManifestFromLookup' {
            It 'Simple lookup' {
                $result = Resolve-ManifestInformation 'pwsh'
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result = $null

                $result = Resolve-ManifestInformation 'cosi'
                $result.ApplicationName | Should -Be 'cosi'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.checkver | Should -Be 'github'
                $result = $null
            }

            It 'Simple versioned lookup' {
                $result = Resolve-ManifestInformation 'pwsh@6.2.3'
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '6.2.3'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result = $null

                $result = Resolve-ManifestInformation 'cosi@7.1.0'
                $result.ApplicationName | Should -Be 'cosi'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result.Version | Should -Be '7.1.0'
                $result.ManifestObject.homepage | Should -Be 'https://github.com/PowerShell/PowerShell'
                $result = $null

                { Resolve-ManifestInformation 'tryharder' } | Should -Throw 'No manifest found for ''tryharder'''
            }

            It 'Specific bucket lookup' {
                $result = Resolve-ManifestInformation 'main/pwsh'
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.Bucket | Should -Be 'main'
                $result = $null

                $result = Resolve-ManifestInformation 'ash258.ash258/cosi'
                $result.ApplicationName | Should -Be 'cosi'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result.Version | Should -Be '7.1.3'
                $result.ManifestObject.checkver | Should -Be 'github'
                $result = $null

                { Resolve-ManifestInformation 'nonexistent/cosi' } | Should -Throw '''nonexistent'' cannot be found'
                { Resolve-ManifestInformation 'main/tryharder' } | Should -Throw 'No manifest found for ''main/tryharder'''
            }

            It 'Specific bucket lookup with existing versioned manifest' {
                $result = Resolve-ManifestInformation 'ash258.ash258/pwsh@6.2.3'
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '6.2.3'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result = $null

                $result = Resolve-ManifestInformation 'main/cosi@7.1.0'
                $result.ApplicationName | Should -Be 'cosi'
                $result.Bucket | Should -Be 'main'
                $result.Version | Should -Be '7.1.0'
                $result.ManifestObject.homepage | Should -Be 'https://github.com/PowerShell/PowerShell'
                $result = $null

                { Resolve-ManifestInformation 'main/pwsh@6.8.0' 6>$null } | Should -Throw 'Cannot generate manifest with version ''6.8.0'''
                { Resolve-ManifestInformation 'ash258.ash258/cosi@8' 6>$null } | Should -Throw 'Cannot generate manifest with version ''8'''
            }

            It 'Simple lookup with version generation' {
                $result = Resolve-ManifestInformation 'pwsh@7.0.6' 6>$null
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '7.0.6'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result.LocalPath.Extension | Should -BeLike '.json'
                $result.LocalPath.BaseName | Should -BeLike 'pwsh-258258--*'
                $result.LocalPath.Directory.BaseName | Should -BeLike 'manifests'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result = $null

                $result = Resolve-ManifestInformation 'cosi@6.2.3' 6>$null
                $result.ApplicationName | Should -Be 'cosi'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result.LocalPath.Extension | Should -BeLike '.yaml'
                $result.LocalPath.BaseName | Should -BeLike 'cosi-258258--*'
                $result.LocalPath.Directory.BaseName | Should -BeLike 'manifests'
                $result.Version | Should -Be '6.2.3'
                $result.ManifestObject.homepage | Should -Be 'https://github.com/PowerShell/PowerShell'
                $result = $null
            }

            It 'Specific bucket lookup with version generation' {
                $result = Resolve-ManifestInformation 'main/pwsh@7.0.6' 6>$null
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Version | Should -Be '7.0.6'
                $result.Bucket | Should -Be 'main'
                $result.LocalPath.Extension | Should -BeLike '.json'
                $result.LocalPath.BaseName | Should -BeLike 'pwsh-258258--*'
                $result.LocalPath.Directory.BaseName | Should -BeLike 'manifests'
                $result.ManifestObject.bin | Should -Be 'pwsh.exe'
                $result = $null

                $result = Resolve-ManifestInformation 'ash258.ash258/pwsh@7.0.6' 6>$null
                $result.ApplicationName | Should -Be 'pwsh'
                $result.Bucket | Should -Be 'ash258.ash258'
                $result.LocalPath.Extension | Should -BeLike '.json'
                $result.LocalPath.BaseName | Should -BeLike 'pwsh-258258--*'
                $result.LocalPath.Directory.BaseName | Should -BeLike 'manifests'
                $result.Version | Should -Be '7.0.6'
                $result.ManifestObject.homepage | Should -Be 'https://github.com/PowerShell/PowerShell'
                $result = $null
            }
        }

        It 'Not supported query' {
            { Resolve-ManifestInformation '@@cosi@@' } | Should -Throw 'Not supported way how to provide manifest'
            { Resolve-ManifestInformation '@1.2.5.8' } | Should -Throw 'Not supported way how to provide manifest'
            { Resolve-ManifestInformation 'ftp://test.json' } | Should -Throw 'Not supported way how to provide manifest'
        }
    }
}
