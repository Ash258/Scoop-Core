# Usage: scoop help <command>
# Summary: Show help for a command

param($cmd)

'core', 'commands', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

reset_aliases

function print_help($cmd) {
    $file = Get-Content (command_path $cmd) -raw

    $usage = usage $file
    $summary = summary $file
    $help = scoop_help $file

    if ($usage) { "$usage`n" }
    if ($help) { $help }
}

function print_summaries {
    $commands = @{ }

    command_files | ForEach-Object {
        $command = command_name $_
        $summary = summary (Get-Content (command_path $command) -raw)
        if (!($summary)) { $summary = '' }
        $commands.add("$command ", $summary) # add padding
    }

    $commands.getenumerator() | Sort-Object Name | Format-Table -HideTableHead -AutoSize -Wrap
}

$exitCode = 0
$commands = commands

if (!($cmd)) {
    Write-UserMessage -Message @(
        'Usage: scoop <command> [<args>]'
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
    Write-UserMessage -Message "scoop help: no such command '$cmd'"
}

exit $exitCode

