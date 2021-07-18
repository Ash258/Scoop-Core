# Usage: scoop bucket [<SUBCOMMAND>] [<OPTIONS>] [<NAME> [<REPOSITORY>]]
# Summary: Manage local scoop buckets.
# Help: Add, list or remove buckets.
#
# Buckets are repositories of manifests available to install. Scoop comes with
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

'core', 'buckets', 'getopt', 'help', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ExitCode = 0
$Options, $Bucket, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop bucket: $_err" -ExitCode 2 }

$Operation = $Bucket[0]
$Name = $Bucket[1]
$Repo = $Bucket[2]

if (!$Operation) { $Operation = 'list' }

switch ($Operation) {
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
        Write-UserMessage -Message "Unknown subcommand: '$Operation'" -Err
        $ExitCode = 2
    }
}

exit $ExitCode
