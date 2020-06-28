# Usage: scoop unhold <app> [options]
# Summary: Unhold an app to enable updates
# Options:
#   -g, --global              Unhold globally installed app

'getopt', 'help', 'Helpers', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

reset_aliases

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { Write-UserMessage -Message "scoop unhold: $err" -Err; exit 2 }
if (!$apps) { Write-UserMessage -Message '<app> missing' -Err; my_usage; exit 1 }

$global = $opt.g -or $opt.global

# TODO: Stop-ScoopExecution
if ($global -and !(is_admin)) { abort 'Admin privileges are required to interact with globally installed apps' 4 }

if (!$apps) {
    my_usage
    exit 1
}

$exitCode = 0
foreach ($app in $apps) {
    # Not at all installed
    if (!(installed $app)) {
        Write-UserMessage -Message "'$app' is not installed." -Err
        $exitCode = 3
        continue
    }

    # Global required, but not installed globally
    if ($global -and (!(installed $app $global))) {
        Write-UserMessage -Message "'$app' not installed globally" -Err
        $exitCode = 3
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

exit $exitCode
