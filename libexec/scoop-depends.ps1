# Usage: scoop depends <app> [options]
# Summary: List dependencies for an app
#
# Options:
#   -h, --help      Show help for this command.

'depends', 'install', 'manifest', 'buckets', 'getopt', 'decompress', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $apps, $err = getopt $args 'a:' 'arch='
$app = $apps[0]
$architecture = default_architecture

if ($err) { Stop-ScoopExecution -Message "scoop depends: $err" -ExitCode 2 }
if (!$app) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }

$deps = @(deps $app $architecture)
if ($deps) { $deps[($deps.length - 1)..0] }

exit 0
