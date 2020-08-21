# Usage: scoop alias [add|list|rm] [<args>]
# Summary: Manage scoop aliases
# Help: Add, remove or list Scoop aliases
#
# Aliases are custom Scoop subcommands that can be created to make common tasks
# easier.
#
# To add an Alias:
#     scoop alias add <name> <command> <description>
#
# e.g.:
#     scoop alias add rm 'scoop uninstall $args[0]' 'Uninstalls an app'
#     scoop alias add upgrade 'scoop update *' 'Updates all apps, just like brew or apt'
#
# Options:
#   -v, --verbose   Show alias description and table headers (works only for 'list')

param(
    [String] $Option,
    [String] $Name,
    $Command,
    [String] $Description,
    [Switch] $Verbose
)

'core', 'help', 'Alias' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$exitCode = 0

switch ($Option) {
    'add' {
        try {
            Add-ScoopAlias -Name $Name -Command $Command -Description $Description
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
        }
    }
    'rm' {
        try {
            Remove-ScoopAlias -Name $Name
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            $exitCode = 3
        }
    }
    'list' {
        Get-ScoopAlias -Verbose:$Verbose
    }
    default {
        Stop-ScoopExecution -Message 'No parameters provided' -Usage (my_usage)
    }
}

exit $exitCode
