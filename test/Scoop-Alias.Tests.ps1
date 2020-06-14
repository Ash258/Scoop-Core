if (!$env:CI) { Write-Host 'SKipping test' }

Describe 'Add-ScoopAlias' -Tag 'Scoop' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\Alias.ps1"

        Mock shimdir { "$env:TMP\Scoopshim" }
        Mock load_cfg { }

        $shimdir = shimdir
        New-Item $shimdir -ItemType Directory -Force | Out-Null
    }

    Context 'alias does not exist' {
        It 'creates a new alias' {
            $aliasFile = "$shimdir\scoop-cosiTest.ps1"
            $aliasFile | Should -Not -Exist

            Add-ScoopAlias -Name 'cosiTest' -Command '"hello, world!"'
            Invoke-Expression $aliasFile | Should -Be 'hello, world!'
        }
    }

    Context 'invalid alias definition' {
        It 'require needed parameters' {
            { Add-ScoopAlias } | Should -Throw
            { Add-ScoopAlias -Name 'cosi' } | Should -Throw
            { Add-ScoopAlias -Name 'cosi' -Command '' } | Should -Throw
        }
    }
}

# TODO: Remove alias test
# TODO: Proper scoop installation tests without mocks
