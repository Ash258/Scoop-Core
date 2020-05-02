. "$PSScriptRoot\..\lib\Alias.ps1"

reset_aliases

describe 'Add-Alias' -Tag 'Scoop' {
    BeforeAll {
        mock shimdir { 'TestDrive:\shim' }
        mock set_config { }
        mock get_config { @{ } }

        $shimdir = shimdir
        New-Item $shimdir -ItemType Directory -Force | Out-Null
    }

    context 'alias does nott exist' {
        it 'creates a new alias' {
            $aliasFile = "$shimdir\scoop-test.ps1"
            $aliasFile | Should -Not -Exist

            Add-Alias -Name 'test' -Command '"hello, world!"'
            Invoke-Expression $aliasFile | Should -Be "hello, world!"
        }
    }
}
