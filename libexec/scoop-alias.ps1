# Usage: scoop alias [add|list|rm|edit|path] [<args>] [options]
# Summary: Manage scoop aliases
# Help: Add, remove, list or edit Scoop aliases
#
# Aliases are custom Scoop subcommands that can be created to make common tasks easier.
#
# To add an Alias:
#     scoop alias add <name> <command> <description>
#
# To edit an Alias inside default system editor:
#     scoop alias edit <name>
#
# To get path of the alias file:
#     scoop alias path <name>
#
# e.g.:
#     scoop alias add test-home 'curl.exe --verbose $args[0] *>&1 | Select-String ''< HTTP/'', ''< Location:''' 'Test URL status code and location'
#
# Options:
#   -h, --help      Show help for this command.
#   -v, --verbose   Show alias description and table headers (works only for 'list').

'core', 'getopt', 'help', 'Alias' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

#region Parameter validation
$opt, $rem, $err = getopt $args 'v' 'verbose'
if ($err) { Stop-ScoopExecution -Message "scoop install: $err" -ExitCode 2 }

$Option = $rem[0]
$Name = $rem[1]
$Command = $rem[2]
$Description = $rem[3]
$Verbose = $opt.v -or $opt.verbose
#endregion Parameter validation
$exitCode = 0

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
    default {
        Stop-ScoopExecution -Message 'No parameters provided' -Usage (my_usage)
    }
}

exit $exitCode
