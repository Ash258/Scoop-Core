'commands' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function usage($text) {
    $text | Select-String '(?m)^# Usage: ([^\n]*)$' | ForEach-Object { 'Usage: ' + $_.matches[0].Groups[1].Value }
}

function summary($text) {
    $text | Select-String '(?m)^# Summary: ([^\n]*)$' | ForEach-Object { $_.matches[0].Groups[1].Value }
}

function scoop_help($text) {
    $help_lines = $text | Select-String '(?ms)^# (?:Help|Options):(.(?!^[^#]))*' | ForEach-Object { $_.matches[0].Value; }
    $help_lines -replace '(?ms)^#\s?(Help: )?'
}

function print_help($cmd) {
    $file = Get-Content (command_path $cmd) -Raw

    $usage = usage $file
    $summary = summary $file
    $help = scoop_help $file

    if ($usage) { Write-UserMessage -Message $usage -Output }
    if ($summary) { Write-UserMessage -Message '', $summary -Output }
    if ($help) { Write-UserMessage -Message '', $help -Output }
}

function print_summaries {
    $commands = @{ }

    command_files | ForEach-Object {
        $command = command_name $_
        $summary = summary (Get-Content (command_path $command) -Raw)
        if (!($summary)) { $summary = '' }
        $commands.Add("$command ", $summary) # add padding
    }

    $commands.GetEnumerator() | Sort-Object -Property 'Name' | Format-Table -AutoSize -HideTableHeaders -Wrap
}

function my_usage {
    # Gets usage for the calling script
    usage (Get-Content $myInvocation.PSCommandPath -Raw)
}
