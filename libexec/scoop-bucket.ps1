# Usage: scoop bucket [<SUCOMMAND>] [<OPTIONS>] [<NAME> [<REPOSITORY>]]
# Summary: Manage local scoop buckets.
# Help: Add, list or remove buckets.
#
# Buckets are repositories of applications available to install. Scoop comes with
# a default (main) bucket, but you can also add buckets that you or others have
# published.
#
# To add a bucket:
#   scoop bucket add <NAME> [<REPOSITORY>]
# eg:
#   scoop bucket add Ash258 https://github.com/Ash258/Scoop-Ash258.git
#   scoop bucket add extras
#
# To remove a bucket:
#   scoop bucket rm versions
# To list all known buckets, use:
#   scoop bucket known
#
# Subcommands:
#   add             Add a new bucket.
#   list            List all locally added buckets. Default subcommand when none is provided.
#   known           List all buckets, which are considered as "known" and could be added without providing repository URL.
#   rm              Remove an already added bucket.
#
# Options:
#   -h, --help      Show help for this command.

'buckets', 'getopt', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $rest, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop bucket: $err" -ExitCode 2 }

$exitCode = 0
$Cmd = $rest[0]
$Name = $rest[1]
$Repo = $rest[2]
if (!$Cmd) { $Cmd = 'list' }

switch ($Cmd) {
    'add' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <NAME> is missing' -Usage (my_usage) }

        try {
            Add-Bucket -Name $Name -RepositoryUrl $Repo
        } catch {
            Stop-ScoopExecution -Message $_.Exception.Message
        }
    }
    'rm' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <NAME> missing' -Usage (my_usage) }

        try {
            Remove-Bucket -Name $Name
        } catch {
            Stop-ScoopExecution -Message $_.Exception.Message
        }
    }
    'known' {
        Get-KnownBucket
    }
    'list' {
        Get-LocalBucket
    }
    default {
        Stop-ScoopExecution -Message 'No parameter provided' -Usage (my_usage)
    }
}

exit $exitCode
