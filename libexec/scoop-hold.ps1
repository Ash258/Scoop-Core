# Usage: scoop hold <apps> [options]
# Summary: Hold an app to disable updates
# Options:
#   -h, --help                Show help for this command.
#   -g, --global              Hold globally installed app.

'getopt', 'Helpers', 'Applications', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { Stop-ScoopExecution -Message "scoop hold: $err" -ExitCode 2 }
if (!$apps) { Stop-ScoopExecution -Message 'Parameter <apps> missing' -Usage (my_usage) }

$global = $opt.g -or $opt.global

if ($global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to interact with globally installed apps' -ExitCode 4 }

$problems = 0
$exitCode = 0
foreach ($app in $apps) {
    # Not at all installed
    if (!(installed $app)) {
        Write-UserMessage -Message "'$app' is not installed." -Err
        ++$problems
        continue
    }

    # Global required, but not installed globally
    if ($global -and (!(installed $app $global))) {
        Write-UserMessage -Message "'$app' not installed globally" -Err
        ++$problems
        continue
    }

    $current = Get-InstalledApplicationInformationProperty -AppName $app -Global:$global -Property 'hold'
    if ($current -and ($current -eq $true)) {
        Write-UserMessage -Message "'$app' is already held" -Warning
        continue
    }

    Set-InstalledApplicationInformationProperty -AppName $app -Global:$global -Property 'hold' -Value $true -Update
    Write-UserMessage -Message "$app is now held and cannot be updated anymore." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
