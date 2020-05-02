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

    exit
    context "alias exists" {
        it "does not change existing alias" {
            $alias_file = "$shimdir\scoop-rm.ps1"
            new-item $alias_file -type file
            $alias_file | should -exist

            add_alias "rm" "test"
            $alias_file | should -FileContentMatch ""
        }
    }
}

describe "rm_alias" {
    mock shimdir { "TestDrive:\shim" }
    mock set_config { }
    mock get_config { @{ } }

    $shimdir = shimdir
    mkdir $shimdir

    context "alias exists" {
        it "removes an existing alias" {
            $alias_file = "$shimdir\scoop-rm.ps1"
            add_alias "rm" '"hello, world!"'

            $alias_file | should -exist
            mock get_config { @(@{"rm" = "scoop-rm" }) }

            rm_alias "rm"
            $alias_file | should -not -exist
        }
    }
}
