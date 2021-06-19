param($bucketdir = "$PSScriptRoot\..\bucket\")

. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe -Tag 'Manifests' 'manifest-validation' {
    BeforeAll {
        $working_dir = setup_working 'manifest'
        $schema = "$PSScriptRoot/../schema.json"
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Newtonsoft.Json.dll"
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Newtonsoft.Json.Schema.dll"
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
    }

    It 'Scoop.Validator is available' {
        ([System.Management.Automation.PSTypeName]'Scoop.Validator').Type | Should -Be 'Scoop.Validator'
    }

    Context 'parse_json function' {
        It 'fails with invalid json' {
            { parse_json "$working_dir\broken_wget.json" } | Should -Throw
            { ConvertFrom-Manifest "$working_dir\broken_wget.json" } | Should -Throw
        }
    }

    Context 'schema validation' {
        It 'fails with broken schema' {
            $validator = New-Object Scoop.Validator("$working_dir/broken_schema.json", $true)
            $validator.Validate("$working_dir/wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_schema.*(line 6).*(position 4)'
        }
        It 'fails with broken manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir/broken_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_wget.*(line 5).*(position 4)'
        }
        It 'fails with invalid manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir/invalid_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 16
            $validator.Errors | Select-Object -First 1 | Should -Match "Property 'randomproperty' has not been defined and the schema does not allow additional properties\."
            $validator.Errors | Select-Object -Last 1 | Should -Match 'Required properties are missing from object: version, description\.'
        }
    }

    Context 'manifest validates against the schema' {
        BeforeAll {
            if ($null -eq $bucketdir) { $bucketdir = "$PSScriptRoot\..\bucket\" }
            if (!(Test-Path $bucketdir)) { New-Item $bucketdir -ItemType 'Directory' -Force }

            $changed_manifests = @()
            $manifest_files = @()
            $allFiles = Get-ChildItem $bucketdir -Recurse

            if ($env:CI -eq $true) {
                $commit = if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT) { $env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT } else { $env:APPVEYOR_REPO_COMMIT }
                if ($commit) {
                    $allChanged = Get-GitChangedFile -Commit $commit

                    # Filter out valid manifests
                    foreach ($ext in $ALLOWED_MANIFEST_EXTENSION) {
                        $changed_manifests += $allChanged | Where-Object { $_ -like "*.$ext" }
                    }
                }
            }

            # Filter out valid manifests
            foreach ($ext in $ALLOWED_MANIFEST_EXTENSION) {
                $manifest_files += $allFiles | Where-Object { $_ -like "*.$ext" }
            }

            $validator = New-Object Scoop.Validator($schema, $true)
        }

        $quota_exceeded = $false

        foreach ($file in $manifest_files) {
            $skip_manifest = ($changed_manifests -inotcontains $file.FullName)
            if (($env:CI -ne $true) -or ($changed_manifests -imatch 'schema.json')) { $skip_manifest = $false }

            It "$file" -Skip:$skip_manifest {
                # TODO: Skip yml for now for schema validation
                if (!$quota_exceeded -and ($file.Extension -notmatch '\.ya?ml$')) {
                    try {
                        $validator.Validate($file.FullName)

                        if ($validator.Errors.Count -gt 0) {
                            Write-Host -f red "      [-] $file has $($validator.Errors.Count) Error$(If($validator.Errors.Count -gt 1) { 's' })!"
                            Write-Host -f yellow $validator.ErrorsAsString
                        }
                        $validator.Errors.Count | Should -Be 0
                    } catch {
                        if ($_.Exception.Message -like '*The free-quota limit of 1000 schema validations per hour has been reached.*') {
                            $quota_exceeded = $true
                            Write-Host -f darkyellow 'Schema validation limit exceeded. Will skip further validations.'
                        } else {
                            throw
                        }
                    }
                }

                $manifest = ConvertFrom-Manifest -LiteralPath $file.FullName
                $url = arch_specific 'url' $manifest '32bit'
                $url64 = arch_specific 'url' $manifest '64bit'

                if (!$url) { $url = $url64 }

                $url | Should -Not -BeNullOrEmpty
            }
        }
    }
}
