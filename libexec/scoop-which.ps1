# Usage: scoop which [<OPTIONS>] <COMMAND>
# Summary: Locate the path to a shim/executable of application that was installed with scoop (similar to 'which' on Linux).
#
# Options:
#   -h, --help      Show help for this command.

'core', 'help', 'commands', 'getopt' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$Opt, $Command, $err = getopt $args

if ($err) { Stop-ScoopExecution -Message "scoop which: $err" -ExitCode 2 }
if (!$Command) { Stop-ScoopExecution -Message 'Parameter <COMMAND> missing' -Usage (my_usage) }

$gcm = $null
try {
    $gcm = Get-Command $Command -ErrorAction 'Stop'
} catch {
    Stop-ScoopExecution -Message "Command '$Command' not found"
}

$ExitCode = 0
$FinalPath = $null
$userShims = shimdir $false | Resolve-Path
$globalShims = shimdir $true # don't resolve: may not exist

if ($gcm.Path -and $gcm.Path.EndsWith('.ps1') -and (($gcm.Path -like "$userShims*") -or ($gcm.Path -like "$globalShims*"))) {
    # This will show path to the real exe instead of the original ps1 file. Should it be right?
    $shimText = Get-Content -LiteralPath $gcm.Path -Encoding 'UTF8'
    # TODO: Drop Invoke-Expression
    $exePath = ($shimText | Where-Object { $_.StartsWith('$path') }) -split ' ' | Select-Object -Last 1 | Invoke-Expression

    # Expand relative path
    if ($exePath -and ![System.IO.Path]::IsPathRooted($exePath)) {
        $exePath = Split-Path $gcm.Path | Join-Path -ChildPath $exePath | Resolve-Path
    } else {
        $exePath = $gcm.Path
    }

    $FinalPath = friendly_path $exePath
} else {
    switch ($gcm.CommandType) {
        'Application' { $FinalPath = $gcm.Source }
        'Alias' {
            $FinalPath = Invoke-ScoopCommand 'which' @($gcm.ResolvedCommandName)
            $ExitCode = $LASTEXITCODE
        }
        default {
            Write-UserMessage -Message 'Not a scoop shim' -Output
            $FinalPath = $gcm.Path
            $ExitCode = 3
        }
    }
}

if ($FinalPath) { Write-UserMessage -Message $FinalPath -Output }

exit $ExitCode
