. "$PSScriptRoot\..\lib\Alias.ps1"

describe 'Add-Alias' -Tag 'Scoop' {
    BeforeAll {
        mock shimdir { "$env:TMP\Scoopshim" }
        mock load_cfg { }

        $shimdir = shimdir
        New-Item $shimdir -ItemType Directory -Force | Out-Null
    }

    context 'alias does not exist' {
        it 'creates a new alias' {
            $aliasFile = "$shimdir\scoop-cosiTest.ps1"
            $aliasFile | Should -Not -Exist

            Add-Alias -Name 'cosiTest' -Command '"hello, world!"'
            Invoke-Expression $aliasFile | Should -Be 'hello, world!'
        }
    }

    context 'invalid alias definition' {
        it 'require needed parameters' {
            { Add-Alias } | Should -Throw
            { Add-Alias -Name 'cosi' } | Should -Throw
            { Add-Alias -Name 'cosi' -Command '' } | Should -Throw
        }
    }
}

# TODO: Remove alias test
# TODO: Proper scoop installation tests without mocks
