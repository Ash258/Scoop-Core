# Usage: scoop which [<OPTIONS>] <COMMAND>
# Summary: Locate the path to a shim/executable of application that was installed with Scoop (similar to 'which' on Linux).
#
# Options:
#   -h, --help      Show help for this command.

'core', 'help', 'commands', 'getopt' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$opt, $command, $err = getopt $args
if ($err) { Stop-ScoopExecution -Message "scoop which: $err" -ExitCode 2 }

if (!$command) { Stop-ScoopExecution -Message 'Parameter <COMMAND> missing' -Usage (my_usage) }

try {
    $gcm = Get-Command $command -ErrorAction 'Stop'
} catch {
    Stop-ScoopExecution -Message "Command '$command' not found"
}

$userShims = shimdir $false | Resolve-Path
$globalShims = shimdir $true # don't resolve: may not exist

$FINAL_PATH = $null
$exitCode = 0

if ($gcm.Path -and $gcm.Path.EndsWith('.ps1') -and (($gcm.Path -like "$userShims*") -or ($gcm.Path -like "$globalShims*"))) {
    $shimText = Get-Content $gcm.Path
    $exePath = ($shimText | Where-Object { $_.StartsWith('$path') }) -split ' ' | Select-Object -Last 1 | Invoke-Expression

    # Expand relative path
    if ($exePath -and ![System.IO.Path]::IsPathRooted($exePath)) {
        $exePath = Split-Path $gcm.Path | Join-Path -ChildPath $exePath | Resolve-Path
    } else {
        $exePath = $gcm.Path
    }

    $FINAL_PATH = friendly_path $exePath
} else {
    switch ($gcm.CommandType) {
        'Application' { $FINAL_PATH = $gcm.Source }
        'Alias' {
            $FINAL_PATH = Invoke-ScoopCommand 'which' @{ 'Command' = $gcm.ResolvedCommandName }
            $exitCode = $LASTEXITCODE
        }
        default {
            Write-UserMessage -Message 'Not a scoop shim'
            $FINAL_PATH = $gcm.Path
            $exitCode = 3
        }
    }
}

if ($FINAL_PATH) { Write-UserMessage -Message $FINAL_PATH -Output }

exit $exitCode
