
. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Resolve-ManifestInformation' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = (setup_working 'manifest' | Resolve-Path).Path
        $SCOOP_BUCKETS_DIRECTORY = $working_dir | Split-Path

        Copy-Item "$working_dir\*" "$SCOOP_BUCKETS_DIRECTORY\ash258.ash258" -Force -Recurse
        Copy-Item "$working_dir\*" "$SCOOP_BUCKETS_DIRECTORY\main" -Force -Recurse

        $SCOOP_BUCKETS_DIRECTORY | Out-Null # PowerShell/PSScriptAnalyzer#1472
    }

    It 'manifest_path' {
        $path = manifest_path 'cosi' 'manifest'
        $path | Should -Be "$working_dir\bucket\cosi.yaml"
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

        $path = manifest_path 'ahoj' 'alfa'
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
    }
}
