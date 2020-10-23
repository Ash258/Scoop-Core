# Usage: scoop help <command> [options]
# Summary: Show help for a command
#
# Options:
#   -h, --help      Show help for this command.

param($cmd)

'help', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0
$commands = commands

if (!($cmd)) {
    Write-UserMessage -Output -Message @(
        'Usage: scoop <command> [<args>]'
        ''
        'Windows command line installer'
        ''
        'General exit codes'
        '   0 - Everything OK'
        '   1 - No parameter provided or usage shown'
        '   2 - Argument parsing error'
        '   3 - General execution error'
        '   4 - Permission/Privileges related issue'
        '   10 + - Number of failed actions (installations, updates, ...)'
        ''
        "Type 'scoop help <command>' to get help for a specific command."
        ''
        'Available commands are:'
    )
    print_summaries
} elseif ($commands -contains $cmd) {
    print_help $cmd
} else {
    $exitCode = 3
    Write-UserMessage -Message "scoop help: no such command '$cmd'" -Output
}

exit $exitCode

