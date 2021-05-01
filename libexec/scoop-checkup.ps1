# Usage: scoop checkup [<OPTIONS>]
# Summary: Check system for pontential problems.
# Help: Perform a series of diagnostic tests to try to identify configurations/issues that may cause problems while using scoop.
#
# Options:
#   -h, --help      Show help for this command.

'core', 'Diagnostic', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$issues = 0
$issues += !(Test-DiagWindowsDefender)
$issues += !(Test-DiagWindowsDefender -Global)
$issues += !(Test-DiagMainBucketAdded)
$issues += !(Test-DiagLongPathEnabled)
$issues += !(Test-DiagEnvironmentVariable)
$issues += !(Test-DiagHelpersInstalled)
$issues += !(Test-DiagDrive)
$issues += !(Test-DiagConfig)
$issues += !(Test-DiagCompletionRegistered)
$issues += !(Test-DiagShovelAdoption)
$issues += !(Test-MainBranchAdoption)
$issues += !(Test-ScoopConfigFile)

if ($issues -gt 0) {
    Write-UserMessage -Message '', "Found $issues potential $(pluralize $issues 'problem' 'problems')." -Warning
    $exitCode = 10 + $issues
} else {
    Write-UserMessage -Message 'No problems identified!' -Success
    $exitCode = 0
}

exit $exitCode
