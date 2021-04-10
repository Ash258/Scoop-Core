
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

    }
}
