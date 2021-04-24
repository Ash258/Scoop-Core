
. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Resolve-ManifestInformation' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = (setup_working 'manifest' | Resolve-Path).Path
    }

    It 'should handle full local path' {
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

    It 'should handle full local path with archived version' {
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

    It 'should handle https manifest' {
        # TODO: Mockup to not download the file
        $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/068225b07cad6baeb46eb1adc26f8207fa423508/bucket/aaaaa.json"
        $result.ApplicationName | Should -Be 'aaaaa'
        $result.Version | Should -Be '0.0.15-12154'
        $result.ManifestObject.checkver.github | Should -Be 'https://github.com/RPCS3/rpcs3-binaries-win'
        $result = $null

        $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/184d2f072798441e8eb03a655dea16f2695ee699/bucket/alfa.yaml"
        $result.ApplicationName | Should -Be 'alfa'
        $result.Version | Should -Be '0.0.15-12154'
        $result.ManifestObject.checkver.github | Should -Be 'https://github.com/RPCS3/rpcs3-binaries-win'
        $result = $null
    }

    It 'should handle https with archived version' {
        $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/068225b07cad6baeb46eb1adc26f8207fa423508/bucket/old/alfa/0.0.15-12060.yaml"
        $result.ApplicationName | Should -Be 'alfa'
        $result.Version | Should -Be '0.0.15-12060'
        $result.ManifestObject.bin | Should -Be 'rpcs3.exe'
        $result = $null

        $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/8117ddcbadc606f5d4576778676e81bfc6dc2e78/bucket/old/aaaaa/0.0.15-11936.json"
        $result.ApplicationName | Should -Be 'aaaaa'
        $result.Version | Should -Be '0.0.15-11936'
        $result.ManifestObject.bin | Should -Be 'rpcs3.exe'
        $result = $null
    }

    It 'should handle manifest lookup' {
        '' | Should -Be ''
        { $result = Resolve-ManifestInformation "pwsh" } | Should -Throw 'Not implemented lookup'
    }

    It 'should handle manifest lookup with version' {
        '' | Should -Be ''
        { $result = Resolve-ManifestInformation "pwsh@7.2.3" } | Should -Throw 'Not implemented lookup'
    }

    It 'should handle bucket/manifest lookup' {
        '' | Should -Be ''
        { $result = Resolve-ManifestInformation "main/pwsh" } | Should -Throw 'Not implemented lookup'
        { $result = Resolve-ManifestInformation "ash258.ash258/pwsh" } | Should -Throw 'Not implemented lookup'
    }

    It 'should handle bucket/manifest lookup with version' {
        '' | Should -Be ''
        { $result = Resolve-ManifestInformation "main/pwsh@7.2.3" } | Should -Throw 'Not implemented lookup'
        { $result = Resolve-ManifestInformation "ash258.ash258/pwsh@7.2.3" } | Should -Throw 'Not implemented lookup'
    }

    It 'should throw' {
        { $result = Resolve-ManifestInformation "@@cosi@@" } | Should -Throw 'Not supported way how to provide manifest'
        { $result = Resolve-ManifestInformation "@1.2.5.8" } | Should -Throw 'Not supported way how to provide manifest'
        { $result = Resolve-ManifestInformation "ftp://test.json" } | Should -Throw 'Not supported way how to provide manifest'
    }
}
