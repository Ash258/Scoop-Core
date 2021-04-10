
. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Resolve-ManifestInformation' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'manifest'
    }

    It 'should handle full local path' {
        $result = Resolve-ManifestInformation "$working_dir\bucket\pwsh.json"
        $result.ApplicationName | Should -Be 'pwsh'
        $result.Version | Should -Be '7.1.3'
        $result.ManifestObject.checkver | Should -Be 'github'
        $result = $null

        # Mix of dividers
        $result = Resolve-ManifestInformation "$working_dir\bucket/cosi.yaml"
        $result.ApplicationName | Should -Be 'cosi'
        $result.Version | Should -Be '7.1.3'
        $result.ManifestObject.checkver | Should -Be 'github'
        $result = $null
    }

    It 'should handle full local path with archived version' {
        $result = Resolve-ManifestInformation "$working_dir\bucket\old\pwsh\6.2.3.yml"
        $result.ApplicationName | Should -Be 'pwsh'
        $result.Version | Should -Be '6.2.3'
        $result.ManifestObject.bin | Should -Be 'pwsh.exe'
        $result = $null

        $result = Resolve-ManifestInformation "$working_dir\bucket\old\cosi\7.1.0.yaml"
        $result.ApplicationName | Should -Be 'cosi'
        $result.Version | Should -Be '7.1.0'
        $result.ManifestObject.bin | Should -Be 'pwsh.exe'
        $result = $null

        $result = Resolve-ManifestInformation "$working_dir\bucket/old\cosi/7.1.0.yaml"
        $result.ApplicationName | Should -Be 'cosi'
        $result.Version | Should -Be '7.1.0'
        $result.ManifestObject.bin | Should -Be 'pwsh.exe'
        $result = $null

        $result = Resolve-ManifestInformation "$($working_dir -replace '\\', '/')/bucket/old/cosi/7.1.0.yaml"
        $result.ApplicationName | Should -Be 'cosi'
        $result.Version | Should -Be '7.1.0'
        $result.ManifestObject.bin | Should -Be 'pwsh.exe'
        $result = $null
    }

    It 'should handle https manifest' {
        '' | Should -Be ''
        # TODO: Mockup to not download the file
        { $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/main/bucket/aaaaa.json" } | Should -Throw 'Not implemented https'
        { $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/main/bucket/alfa.yaml" } | Should -Throw 'Not implemented https'
    }

    It 'should handle https with archived version' {
        '' | Should -Be ''
        # TODO: Mockup to not download the file
        { $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/main/bucket/old/alfa/0.0.15-12060.yaml" } | Should -Throw 'Not implemented https'
        { $result = Resolve-ManifestInformation "https://raw.githubusercontent.com/Ash258/GithubActionsBucketForTesting/main/bucket/old/aaaaa/0.0.15-12060.json" } | Should -Throw 'Not implemented https'
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
    }

    It 'should handle bucket/manifest lookup with version' {
        '' | Should -Be ''
        { $result = Resolve-ManifestInformation "main/pwsh@7.2.3" } | Should -Throw 'Not implemented lookup'
    }

    It 'should throw' {
        { $result = Resolve-ManifestInformation "@@cosi@@" } | Should -Throw 'Not supported way how to provide manifest'
        { $result = Resolve-ManifestInformation "@1.2.5.8" } | Should -Throw 'Not supported way how to provide manifest'
        { $result = Resolve-ManifestInformation "ftp://test.json" } | Should -Throw 'Not supported way how to provide manifest'
    }
}
