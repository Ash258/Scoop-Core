# Usage: scoop unhold <apps> [options]
# Summary: Unhold an app to enable updates
#
# Options:
#   -h, --help           Show help for this command.
#   -g, --global         Unhold globally installed app.

'core', 'getopt', 'help', 'Helpers', 'Applications' | ForEach-Object {
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

    if (($null -eq $current) -or ($current -eq $false)) {
        Write-UserMessage -Message "'$app' is not held" -Warning
        continue
    }

    Set-InstalledApplicationInformationPropertyValue @splat -Value $false -Force
    Write-UserMessage -Message "$app is no longer held and can be updated again." -Success
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

exit $exitCode
