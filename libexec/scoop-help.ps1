# Usage: scoop help [<OPTIONS>] [<COMMAND>]
# Summary: Show help for specific scoop command or scoop itself.
#
# Options:
#   -h, --help      Show help for this command.

'help', 'Helpers', 'getopt' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Options, $Command, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop help: $_err" -ExitCode 2 }

if (!($Command)) {
    Write-UserMessage -Output -Message @(
        'Usage: scoop [<COMMAND>] [<OPTIONS>]'
        ''
        'Windows command line installer'
        ''
        'General exit codes:'
        '   0 - Everything OK'
        '   1 - No parameter provided or usage shown'
        '   2 - Argument parsing error'
        '   3 - General execution error'
        '   4 - Permission/Privileges related issue'
        '   10+ - Number of failed actions (installations, updates, ...)'
        ''
        'Type ''scoop help <COMMAND>'' to get help for a specific command.'
        ''
        'Available commands are:'
    )
    print_summaries
} elseif ((commands) -contains $Command) {
    print_help $Command
} else {
    Write-UserMessage -Message "scoop help: no such command '$Command'" -Output
    $ExitCode = 3
}

exit $ExitCode
