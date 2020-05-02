# Usage: scoop checkup
# Summary: Check for potential problems
# Help: Performs a series of diagnostic tests to try to identify things that may
# cause problems with Scoop.

'core', 'Diagnostic' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

$issues = 0
$issues += !(check_windows_defender $false)
$issues += !(check_windows_defender $true)
$issues += !(check_main_bucket)
$issues += !(check_long_paths)
$issues += !(check_envs_requirements)
$issues += !(check_helpers_installed)
$issues += !(check_drive)

if ($issues) {
    Write-UserMessage -Message "Found $issues potential $(pluralize $issues 'problem' 'problems')." -Warning
} else {
    Write-UserMessage -Message 'No problems identified!' -Success
}

exit 0
