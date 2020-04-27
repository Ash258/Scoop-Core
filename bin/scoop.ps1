#Requires -Version 5
param($cmd)

Set-StrictMode -off

'core', 'git', 'buckets', 'commands' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$commands = commands
if ('--version' -contains $cmd -or (!$cmd -and '-v' -contains $args)) {
    Push-Location $(versiondir 'scoop' 'current')
    write-host "Current Scoop version:"
    Invoke-Expression "git --no-pager log --oneline HEAD -n 1"
    write-host ""
    Pop-Location

    Get-LocalBucket | ForEach-Object {
        Push-Location (Find-BucketDirectory $_ -Root)
        if(test-path '.git') {
            write-host "'$_' bucket:"
            Invoke-Expression "git --no-pager log --oneline HEAD -n 1"
            write-host ""
        }
        Pop-Location
    }
}
elseif (@($null, '--help', '/?') -contains $cmd -or $args[0] -contains '-h') { exec 'help' $args }
elseif ($commands -contains $cmd) { exec $cmd $args }
else { "scoop: '$cmd' isn't a scoop command. See 'scoop help'."; exit 1 }
