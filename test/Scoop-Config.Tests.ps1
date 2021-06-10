. "$PSScriptRoot\..\lib\core.ps1"

Describe 'config' -Tag 'Scoop' {
    BeforeAll {
        $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 }, "five": true, "six": false, "seven": "\/Date(1529917395805)\/", "eight": "2019-03-18T15:22:09.3930000+00:00" }'
    }

    It 'converts JSON to PSObject' {
        $obj = ConvertFrom-Json $json

        $obj.one | Should -BeExactly 1
        $obj.two[0].a | Should -Be 'a'
        $obj.two[1] | Should -Be 'b'
        $obj.two[2] | Should -BeExactly 2
        $obj.three.four | Should -BeExactly 4
        $obj.five | Should -BeTrue
        $obj.six | Should -BeFalse
        $obj.seven | Should -BeOfType [System.DateTime]
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $obj.eight | Should -BeOfType [System.String]
        } else {
            $obj.eight | Should -BeOfType [System.DateTime]
        }
    }

    It 'load_config should return PSObject' {
        Mock Get-Content { $json }
        Mock Test-Path { $true }
        (load_cfg 'file') | Should -Not -BeNullOrEmpty
        (load_cfg 'file') | Should -BeOfType [System.Management.Automation.PSObject]
        (load_cfg 'file').one | Should -BeExactly 1
    }

    It 'get_config should return exactly the same values' {
        $SCOOP_CONFIGURATION = ConvertFrom-Json $json
        get_config 'does_not_exist' 'default' | Should -Be 'default'

        get_config 'one' | Should -BeExactly 1
        (get_config 'two')[0].a | Should -Be 'a'
        (get_config 'two')[1] | Should -Be 'b'
        (get_config 'two')[2] | Should -BeExactly 2
        (get_config 'three').four | Should -BeExactly 4
        get_config 'five' | Should -BeTrue
        get_config 'six' | Should -BeFalse
        get_config 'seven' | Should -BeOfType [System.DateTime]
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            get_config 'eight' | Should -BeOfType [System.String]
        } else {
            get_config 'eight' | Should -BeOfType [System.DateTime]
        }
    }

    <#
    It "set_config should create a new PSObject and ensure existing directory" {
        $SCOOP_CONFIGURATION = $null
        $SCOOP_CONFIGURATION_FILE = "$PSScriptRoot\.scoop"

        Mock ensure { $PSScriptRoot } -Verifiable -ParameterFilter { $dir -eq (Split-Path -Path $SCOOP_CONFIGURATION_FILE) }
        Mock Set-Content { } -Verifiable -ParameterFilter { $Path -eq $SCOOP_CONFIGURATION_FILE }
        Mock ConvertTo-Json { '' } -Verifiable -ParameterFilter { $InputObject -is [System.Management.Automation.PSObject] }

        set_config 'does_not_exist' 'default'

        Assert-VerifiableMock
    }

    It "set_config should remove a value if set to `$null" {
        $SCOOP_CONFIGURATION = New-Object PSObject
        $SCOOP_CONFIGURATION | Add-Member -MemberType NoteProperty -Name 'should_be_removed' -Value 'a_value'
        $SCOOP_CONFIGURATION | Add-Member -MemberType NoteProperty -Name 'should_stay' -Value 'another_value'
        $SCOOP_CONFIGURATION_FILE = "$PSScriptRoot\.scoop"

        Mock Set-Content { } -Verifiable -ParameterFilter { $Path -eq $SCOOP_CONFIGURATION_FILE }
        Mock ConvertTo-Json { '' } -Verifiable -ParameterFilter { $InputObject -is [System.Management.Automation.PSObject] }

        $SCOOP_CONFIGURATION = set_config 'should_be_removed' $null
        $SCOOP_CONFIGURATION.should_be_removed | Should -BeNullOrEmpty
        $SCOOP_CONFIGURATION.should_stay | Should -Be 'another_value'

        Assert-VerifiableMock
    }
    #>
}
