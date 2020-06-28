# Usage: scoop depends <app>
# Summary: List dependencies for an app

'depends', 'install', 'manifest', 'buckets', 'getopt', 'decompress', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

reset_aliases

$opt, $apps, $err = getopt $args 'a:' 'arch='
$app = $apps[0]

if ($err -or !$app) { Write-UserMessage -Message '<app> missing' -Err; my_usage; exit 1 }

$architecture = default_architecture
try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    # TODO: Stop-ScoopExecution
    abort "ERROR: $_" 2
}

$deps = @(deps $app $architecture)
if ($deps) { $deps[($deps.length - 1)..0] }

exit 0
