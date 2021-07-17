# Usage: scoop hold [<OPTIONS>] <APP>...
# Summary: Hold an application(s) to disable updates.
# Help: Application which is configured as held, cannot be updated, unless it is un-holded manually.
#
# Options:
#   -h, --help                Show help for this command.
#   -g, --global              Hold globally installed application(s).

'core', 'getopt', 'help', 'Helpers', 'Applications' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = Resolve-GetOpt $args 'g' 'global'

if ($_err) { Stop-ScoopExecution -Message "scoop hold: $_err" -ExitCode 2 }
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

    if (($null -ne $current) -and ($current -eq $true)) {
        Write-UserMessage -Message "'$app' is already held" -Warning
        continue
    }

    Set-InstalledApplicationInformationPropertyValue @splat -Value $true -Force
    Write-UserMessage -Message "$app is now held and cannot be updated anymore" -Success
}

if ($Problems -gt 0) { $ExitCode = 10 + $Problems }

exit $ExitCode
