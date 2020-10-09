# Usage: scoop bucket [add|list|known|rm] [<args>] [options]
# Summary: Manage Scoop buckets
# Help: Add, list or remove buckets.
#
# Buckets are repositories of apps available to install. Scoop comes with
# a default bucket, but you can also add buckets that you or others have
# published.
#
# To add a bucket:
#   scoop bucket add <name> [<repo>]
# eg:
#   scoop bucket add Ash258 https://github.com/Ash258/Scoop-Ash258.git
#   scoop bucket add extras
#
# To remove a bucket:
#   scoop bucket rm versions
# To list all known buckets, use:
#   scoop bucket known
#
# Options:
#   -h, --help      Show help for this command.

param($Cmd, $Name, $Repo)

'buckets', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0
switch ($Cmd) {
    'add' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <name> is missing' -Usage (my_usage) }

        try {
            Add-Bucket -Name $Name -RepositoryUrl $Repo
        } catch {
            Stop-ScoopExecution -Message $_.Exception.Message
        }
    }
    'rm' {
        if (!$Name) { Stop-ScoopExecution -Message 'Parameter <name> missing' -Usage (my_usage) }

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
