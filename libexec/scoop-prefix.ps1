# Usage: scoop prefix [<OPTIONS>] <APP>
# Summary: Return the location/path of installed application.
#
# Options:
#   -h, --help      Show help for this command.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('buckets', 'Get-KnownBucket'),
    @('manifest', 'Resolve-ManifestInformation')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")    }
}

$ExitCode = 0
$Options, $Application, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop prefix: $_err" -ExitCode 2 }
if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

# TODO: Test if application is installed first
#       Same flow as for hold/unhold
# TODO: Add --global
# TODO: Respect NO_JUNCTIONS
$Application = $Application[0]
$ApplicationPath = versiondir $Application 'current' $false

if (!(Test-Path $ApplicationPath)) { $ApplicationPath = versiondir $Application 'current' $true }

if (Test-Path $ApplicationPath) {
    Write-UserMessage -Message $ApplicationPath -Output
} else {
    Write-UserMessage -Message "'$Application' is not installed" -Err
    $ExitCode = 3
}

exit $ExitCode
