. "$PSScriptRoot\..\lib\Alias.ps1"

describe 'Add-Alias' -Tag 'Scoop' {
    BeforeAll {
        mock shimdir { "$env:TEMP\shim" }
        # TODO: Proper config
        mock set_config { }
        mock get_config { @{ } }

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

    context 'alias exists' {
        it 'does not change existing alias' {
            $aliasFile = "$shimdir\scoop-cosiTest.ps1"

            $aliasFile | Should -Exist
            $aliasFile | Should -FileContentMatch '"hello, world!"'
        }
    }
}
