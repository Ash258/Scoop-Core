# Usage: scoop depends [<OPTIONS>] <APP>
# Summary: List dependencies for an application.
#
# Options:
#   -h, --help      Show help for this command.

'depends', 'install', 'manifest', 'buckets', 'getopt', 'decompress', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'a:' 'arch='
# TODO: Multiple apps?
$app = $apps[0]

if ($err) { Stop-ScoopExecution -Message "scoop depends: $err" -ExitCode 2 }
if (!$app) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$deps = @(deps $app (default_architecture))
if ($deps) { $deps[($deps.length - 1)..0] }

exit 0
