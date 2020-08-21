# Usage: scoop unhold <apps> [options]
# Summary: Unhold an app to enable updates
# Options:
#   -g, --global              Unhold globally installed app

'getopt', 'help', 'Helpers', 'manifest' | ForEach-Object {
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

    # TODO: Respect NO_JUNCTION
    $dir = versiondir $app 'current' $global
    $json = install_info $app 'current' $global
    if (!$json.hold -or ($json.hold -eq $false)) {
        Write-UserMessage -Message "'$app' is not held" -Warning
        continue
    }
    # TODO: Remove member instead of duplicating object
    $install = @{ }
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }
    $install.hold = $null
    save_install_info $install $dir
    Write-UserMessage -Message "$app is no longer held and can be updated again." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
