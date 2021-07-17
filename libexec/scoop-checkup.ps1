# Usage: scoop checkup [<OPTIONS>]
# Summary: Check system for pontential problems.
# Help: Perform a series of diagnostic tests to try to identify configurations/issues that may cause problems while using scoop.
#
# Options:
#   -h, --help      Show help for this command.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('Diagnostic', 'Test-DiagMainBucketAdded')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")    }
}

$ExitCode = 0
$Problems = 0
$Options, $null, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop checkup: $_err" -ExitCode 2 }

$Problems += !(Test-DiagWindowsDefender)
$Problems += !(Test-DiagWindowsDefender -Global)
$Problems += !(Test-DiagMainBucketAdded)
$Problems += !(Test-DiagLongPathEnabled)
$Problems += !(Test-DiagEnvironmentVariable)
$Problems += !(Test-DiagHelpersInstalled)
$Problems += !(Test-DiagDrive)
$Problems += !(Test-DiagConfig)
$Problems += !(Test-DiagCompletionRegistered)
$Problems += !(Test-DiagShovelAdoption)
$Problems += !(Test-MainBranchAdoption)
$Problems += !(Test-ScoopConfigFile)

if ($Problems -gt 0) {
    Write-UserMessage -Message '', "Found $Problems potential $(pluralize $Problems 'problem' 'problems')." -Warning
    $ExitCode = 10 + $Problems
} else {
    Write-UserMessage -Message 'No problems identified!' -Success
}

exit $ExitCode
