# Usage: scoop alias [<SUBCOMMAND>] [<OPTIONS>] [<NAME> <COMMAND> <DESCRIPTION>]
# Summary: Manage scoop aliases.
# Help: Add, remove, list or edit scoop aliases.
#
# Aliases are custom scoop subcommands that can be created to make common tasks easier.
# It could be any valid PowerShell script/command.
#
# To add an alias:
#     scoop alias add <NAME> <COMMAND> <DESCRIPTION>
# Then it could be easily executed as it would be normal scoop command:
#     scoop <NAME>
#
# To remove an alias:
#     scoop alias rm <NAME>
#
# To edit an alias inside default system editor:
#     scoop alias edit <NAME>
#
# To get path of the alias file:
#     scoop alias path <NAME>
#
# e.g.:
#     scoop alias add test-home 'curl.exe --verbose $args[0] *>&1 | Select-String ''< HTTP/'', ''< Location:''' 'Test URL status code and location'
#
# Subcommands:
#   add             Add a new alias.
#   list            List all already added aliases. Default subcommand when none is provided.
#   rm              Remove an already added alias.
#   edit            Open specified alias executable in default system text editor.
#   path            Show path to the executable of specified alias.
#
# Options:
#   -h, --help      Show help for this command.
#   -v, --verbose   Show alias description and table headers (works only for 'list').

'core', 'getopt', 'help', 'Helpers', 'Alias' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: Add --global - Ash258/Scoop-Core#5

$ExitCode = 0
$Options, $Alias, $_err = getopt $args 'v' 'verbose'

if ($_err) { Stop-ScoopExecution -Message "scoop alias: $_err" -ExitCode 2 }

$Operation = $Alias[0]
$Name = $Alias[1]
$Command = $Alias[2]
$Description = $Alias[3]
$Verbose = $Options.v -or $Options.verbose

if (!$Operation) { $Operation = 'list' }

switch ($Operation) {
    'add' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <NAME> missing' -Usage (my_usage) }

        try {
            Add-ScoopAlias -Name $Name -Command $Command -Description $Description
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $ExitCode = 3
            break
        }

        Write-UserMessage -Message "Alias '$Name' added" -Success
    }
    'rm' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <NAME> missing' -Usage (my_usage) }

        try {
            Remove-ScoopAlias -Name $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $ExitCode = 3
            break
        }

        Write-UserMessage -Message "Alias '$Name' removed" -Success
    }
    'list' {
        Get-ScoopAlias -Verbose:$Verbose
    }
    { $_ -in 'edit', 'path' } {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <NAME> missing' -Usage (my_usage) }

        try {
            $path = Get-ScoopAliasPath -AliasName $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $ExitCode = 3
            break
        }

        if (Test-Path -LiteralPath $path -PathType 'Leaf') {
            if ($Operation -eq 'edit') {
                Start-Process $path
            } elseif ($Operation -eq 'path') {
                Write-UserMessage -Message $path -Output
            }
        } else {
            Write-UserMessage -Message "Shim for alias '$Name' does not exist" -Err
            $ExitCode = 3
        }
    }
    default {
        Write-UserMessage -Message "Unknown subcommand: '$Operation'" -Err
        $ExitCode = 2
    }
}

exit $ExitCode
