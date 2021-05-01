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
#   edit            Open specified alias executable in default system editor.
#   path            Show path to the executable of specified alias.
#
# Options:
#   -h, --help      Show help for this command.
#   -v, --verbose   Show alias description and table headers (works only for 'list').

'core', 'getopt', 'help', 'Alias' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: Add --global - Ash258/Scoop-Core#5

$opt, $rem, $err = getopt $args 'v' 'verbose'
if ($err) { Stop-ScoopExecution -Message "scoop alias: $err" -ExitCode 2 }

$exitCode = 0
$Option = $rem[0]
$Name = $rem[1]
$Command = $rem[2]
$Description = $rem[3]
$Verbose = $opt.v -or $opt.verbose

if (!$Option) { $Option = 'list' }

switch ($Option) {
    'add' {
        try {
            Add-ScoopAlias -Name $Name -Command $Command -Description $Description
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
            break
        }

        Write-UserMessage -Message "Alias '$Name' added" -Success
    }
    'rm' {
        try {
            Remove-ScoopAlias -Name $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
            break
        }

        Write-UserMessage -Message "Alias '$Name' removed" -Success
    }
    'list' {
        Get-ScoopAlias -Verbose:$Verbose
    }
    { $_ -in 'edit', 'path' } {
        try {
            $path = Get-ScoopAliasPath -AliasName $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
            break
        }

        if (Test-Path $path -PathType 'Leaf') {
            if ($Option -eq 'edit') {
                Start-Process $path
            } elseif ($Option -eq 'path') {
                Write-UserMessage -Message $path -Output
            }
        } else {
            Write-UserMessage -Message "Shim for alias '$Name' does not exist." -Err
            $exitCode = 3
        }
    }
}

exit $exitCode
