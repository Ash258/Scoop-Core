# Usage: scoop which <command>
# Summary: Locate a shim/executable (similar to 'which' on Linux)
# Help: Locate the path to a shim/executable that was installed with Scoop (similar to 'which' on Linux)
param([String] $Command)

'core', 'help', 'commands' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

if (!$command) { Write-UserMessage '<command> missing' -Err; my_usage; exit 1 }

try {
    $gcm = Get-Command $Command -ErrorAction Stop
} catch {
    # TODO: Stop-ScoopExecution
    abort "Command '$command' not found" 3
}

$userShims = shimdir $false | Resolve-Path
# TODO: Get rid of fullpath
$globalShims = fullpath (shimdir $true) # don't resolve: may not exist

$FINAL_PATH = $null
$FINAL_EXIT_CODE = 0

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
        'Alias' { $FINAL_PATH = exec 'which'  @{ 'Command' = $gcm.ResolvedCommandName } }
        default {
            Write-UserMessage -Message 'Not a scoop shim'
            $FINAL_PATH = $gcm.Path
            $FINAL_EXIT_CODE = 2
        }
    }
}

if ($FINAL_PATH) { Write-UserMessage $FINAL_PATH }

exit $FINAL_EXIT_CODE
