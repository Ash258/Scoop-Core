# Usage: scoop depends [<OPTIONS>] <APP>
# Summary: List dependencies for an application.
#
# Options:
#   -h, --help                  Show help for this command.
#   -a, --arch <32bit|64bit>    Use the specified architecture, if the application's manifest supports it.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'getopt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('depends', 'script_deps')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")    }
}

$ExitCode = 0
$Options, $Applications, $_err = getopt $args 'a:' 'arch='

if ($_err) { Stop-ScoopExecution -Message "scoop depends: $_err" -ExitCode 2 }

# TODO: Multiple apps?
$Application = $Applications[0]
$Architecture = Resolve-ArchitectureParameter -Architecture $Options.a, $Options.arch

if (!$Application) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

# TODO: Installed dependencies are not listed. Should they be shown??
$deps = @(deps $Application $Architecture)
if ($deps) { $deps[($deps.Length - 1)..0] | Write-UserMessage -Output }

exit $ExitCode
