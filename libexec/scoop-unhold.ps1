# Usage: scoop unhold <apps> [options]
# Summary: Unhold an app to enable updates
#
# Options:
#   -h, --help           Show help for this command.
#   -g, --global         Unhold globally installed app.

'getopt', 'Helpers', 'Applications', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { Stop-ScoopExecution -Message "scoop unhold: $err" -ExitCode 2 }
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
    if (!$current -or ($current -eq $false)) {
        Write-UserMessage -Message "'$app' is not held" -Warning
        continue
    }

    Set-InstalledApplicationInformationProperty -AppName $app -Global:$global -Property 'hold' -Value @($false) -Update
    Write-UserMessage -Message "$app is no longer held and can be updated again." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
