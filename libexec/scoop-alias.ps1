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
#     scoop alias add rm 'scoop uninstall $args[0]' 'Uninstalls an app'
#     scoop alias add upgrade 'scoop update *' 'Updates all apps, just like brew or apt'
#     scoop config aria '' 'Switch '
#
# Options:
#   -h, --help      Show help for this command.
#   -v, --verbose   Show alias description and table headers (works only for 'list').

# param(
#     [String] $Option,
#     [String] $Name,
#     $Command,
#     [String] $Description,
#     [Switch] $Verbose
# )

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
$exitCode = 0
Write-Host 'Option:', $Option
Write-Host 'Name:', $Name
Write-Host 'Command:', $Command
Write-Host 'Description:', $Description
Write-Host 'Verbose:', $Verbose

switch ($Option) {
    'add' {
        break
        try {
            Add-ScoopAlias -Name $Name -Command $Command -Description $Description
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
        }
    }
    'rm' {
        break
        try {
            Remove-ScoopAlias -Name $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
        }
    }
    'list' {
        break
        Write-Host $Verbose
        Get-ScoopAlias -Verbose:$Verbose
    }
    'edit' {
        break
        try {
            $path = Get-ScoopAliasPath -AliasName $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
            break
        }

        if (Test-Path $path -PathType Leaf) {
            Start-Process $path
        } else {
            Write-UserMessage -Message "Shim for alias '$Name' does not exist." -Err
            $exitCode = 3
        }
    }
    'path' {
        break
        try {
            $path = Get-ScoopAliasPath -AliasName $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
            break
        }

        if (Test-Path $path -PathType Leaf) { Write-UserMessage -Message $path -Output }
    }
    default {
        Stop-ScoopExecution -Message 'No parameters provided' -Usage (my_usage)
    }
}

exit $exitCode
