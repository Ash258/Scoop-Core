# Usage: scoop hold <apps> [options]
# Summary: Hold an app to disable updates
# Options:
#   -g, --global              Hold globally installed app

'getopt', 'help', 'Helpers', 'manifest' | ForEach-Object {
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

    # TODO: Respect NO_JUNCTION
    $dir = versiondir $app 'current' $global
    $json = install_info $app 'current' $global
    if ($json.hold -and ($json.hold -eq $true)) {
       Write-UserMessage -Message "'$app' is already held" -Warning
       continue
    }
    $install = @{ }
    # TODO: Add-member instead of duplicating of whole object
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }
    $install.hold = $true
    save_install_info $install $dir
    Write-UserMessage -Message "$app is now held and cannot be updated anymore." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
