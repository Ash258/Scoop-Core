function command_files {
    $libExec = Join-Path $PSScriptRoot '..\libexec'
    $shims = Join-Path $SCOOP_ROOT_DIRECTORY 'shims'

    return Get-ChildItem $libExec, $shims | Where-Object -Property Name -Match -Value 'scoop-.*?\.ps1$'
}

function command_name($filename) {
    $filename.name | Select-String 'scoop-(.*?)\.ps1$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
}

function commands {
    command_files | ForEach-Object { command_name $_ }
}

function command_path($cmd) {
    $cmd_path = Join-Path $PSScriptRoot "..\libexec\scoop-$cmd.ps1"

    # Built in commands
    if (!(Test-Path $cmd_path)) {
        # Get path from shim
        $shim_path = Join-Path $SCOOP_ROOT_DIRECTORY "shims\scoop-$cmd.ps1"
        $line = ((Get-Content $shim_path) | Where-Object { $_.StartsWith('$path') })
        if ($line) {
            Invoke-Expression -Command "$line"
            $cmd_path = $path
        } else { $cmd_path = $shim_path }
    }

    return $cmd_path
}

function Invoke-ScoopCommand {
    param($cmd, $arguments)

    & (command_path $cmd) @arguments
}
