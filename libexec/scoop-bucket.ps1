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
#   scoop bucket add extras https://github.com/lukesampson/scoop-extras.git
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
    'list' { Get-LocalBucket }
    'known' { known_buckets }
    default { my_usage; $exitCode = 1 }
}

exit $exitCode
