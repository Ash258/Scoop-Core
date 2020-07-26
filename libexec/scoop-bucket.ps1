# Usage: scoop bucket [add|list|known|rm] [<args>]
# Summary: Manage Scoop buckets
# Help: Add, list or remove buckets.
#
# Buckets are repositories of apps available to install. Scoop comes with
# a default bucket, but you can also add buckets that you or others have
# published.
#
# To add a bucket:
#   scoop bucket add <name> [<repo>]
#
# e.g.:
#   scoop bucket add Ash258 https://github.com/Ash258/Scoop-Ash258.git
#
# Since the 'extras' bucket is known to Scoop, this can be shortened to:
#   scoop bucket add extras
#
# To list all known buckets, use:
#   scoop bucket known

param($Cmd, $Name, $Repo)

'buckets', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

# TODO: Remove
$usage_add = 'usage: scoop bucket add <name> [<repo>]'
$usage_rm = 'usage: scoop bucket rm <name>'

$exitCode = 0
switch ($Cmd) {
    'add' { add_bucket $Name $Repo }
    'rm' { rm_bucket $Name }
    'known' { known_buckets }
    'list' { Get-LocalBucket }
    default { Stop-ScoopExecution -Message 'No parameter provided' -Usage (my_usage) }
}

exit $exitCode
