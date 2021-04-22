# Usage: scoop hold <apps> [options]
# Summary: Hold an app to disable updates
# Options:
#   -h, --help                Show help for this command.
#   -g, --global              Hold globally installed app.

'core', 'getopt', 'help', 'Helpers', 'Applications' | ForEach-Object {
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

    # Globally installed, but required locally
    if (!$global -and ((installed $app $true))) {
        Write-UserMessage -Message "'$app' installed globally" -Err
        ++$problems
        continue
    }

    $splat = @{ 'AppName' = $app; 'Global' = $global }
    $info = Get-InstalledApplicationInformation @splat
    $splat.Add('Property', 'hold')
    $splat.Add('InputObject', $info)
    $current = Get-InstalledApplicationInformationPropertyValue @splat

    if (($null -ne $current) -and ($current -eq $true)) {
        Write-UserMessage -Message "'$app' is already held" -Warning
        continue
    }

    Set-InstalledApplicationInformationPropertyValue @splat -Value $true -Force
    Write-UserMessage -Message "$app is now held and cannot be updated anymore." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
