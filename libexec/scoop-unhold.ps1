# Usage: scoop unhold [<OPTIONS>] <APP>...
# Summary: Unhold an installed application(s) to enable updates.
#
# Options:
#   -h, --help           Show help for this command.
#   -g, --global         Unhold globally installed application(s).

'core', 'getopt', 'help', 'Helpers', 'Applications' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = getopt $args 'g' 'global'

if ($_err) { Stop-ScoopExecution -Message "scoop unhold: $_err" -ExitCode 2 }
if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$Global = $Options.g -or $Options.global

if ($Global -and !(is_admin)) { Stop-ScoopExecution -Message 'Admin privileges are required to interact with globally installed applications' -ExitCode 4 }

foreach ($app in $Applications) {
    # Not at all installed
    if (!(installed $app)) {
        Write-UserMessage -Message "'$app' is not installed" -Err
        ++$Problems
        continue
    }

    # Global required, but not installed globally
    if ($Global -and (!(installed $app $Global))) {
        Write-UserMessage -Message "'$app' not installed globally" -Err
        ++$Problems
        continue
    }

    # Globally installed, but required locally
    if (!$Global -and ((installed $app $true))) {
        Write-UserMessage -Message "'$app' installed globally" -Err
        ++$Problems
        continue
    }

    $splat = @{ 'AppName' = $app; 'Global' = $Global }
    $info = Get-InstalledApplicationInformation @splat
    $splat.Add('Property', 'hold')
    $splat.Add('InputObject', $info)
    $current = Get-InstalledApplicationInformationPropertyValue @splat

    if (($null -eq $current) -or ($current -eq $false)) {
        Write-UserMessage -Message "'$app' is not held" -Warning
        continue
    }

    Set-InstalledApplicationInformationPropertyValue @splat -Value $false -Force
    Write-UserMessage -Message "'$app' is no longer held and can be updated again" -Success
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
