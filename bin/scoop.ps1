#Requires -Version 5
param([string] $cmd)

Set-StrictMode -Off

if (($PSVersionTable.PSVersion.Major) -lt 5) {
    Write-Host @'
PowerShell 5 or later is required
Upgrade PowerShell: 'https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7.1'
'@ -ForegroundColor 'DarkRed'
    exit 1
}

'core', 'buckets', 'Helpers', 'commands', 'Git' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

Reset-Alias

$exitCode = 0

# Powershell automatically bind bash like short parameters as $args, and does not put it in $cmd parameter
# ONLY if:
# - No command passed
# - -v or --version passed
$version = ($cmd -eq '--version') -or (!$cmd -and ($args.Contains('-v')))

# Scoop itself help should be shown only if explicitly asked:
# - No version asked
# - No command passed
# - /?, /help,, /h, --help, -h passed
$scoopHelp = !$version -and (!$cmd -or (($cmd -in @($null, '--help', '/?', '/help', '/h')) -or (!$cmd -and ($args.Contains('-h')))))

# Valid command execution
$validCommand = $cmd -and ($cmd -in (commands))

# Command help should be shown only if:
# - No help for scoop asked
# - $cmd is passed
# - --help, -h is in $args
$commandHelp = !$scoopHelp -and $validCommand -and (($args.Contains('--help')) -or ($args.Contains('-h')))

if ($version) {
    Write-UserMessage -Message "PowerShell version: $($PSVersionTable.PSVersion)" -Output
    Write-UserMessage -Message 'Current Scoop (Shovel) version:' -Output
    Invoke-GitCmd -Command 'VersionLog' -Repository (versiondir 'scoop' 'current')

    # TODO: Export to lib/buckets
    Get-LocalBucket | ForEach-Object {
        $b = Find-BucketDirectory $_ -Root

        if (Join-Path $b '.git' | Test-Path -PathType Container) {
            Write-UserMessage -Message "'$_' bucket:" -Output
            Invoke-GitCmd -Command 'VersionLog' -Repository $b
            Write-UserMessage -Message '' -Output
        }
    }
} elseif ($scoopHelp) {
    Invoke-ScoopCommand 'help'
    $exitCode = $LASTEXITCODE
} elseif ($commandHelp) {
    Invoke-ScoopCommand 'help' @{ 'cmd' = $cmd }
    $exitCode = $LASTEXITCODE
} elseif ($validCommand) {
    Invoke-ScoopCommand $cmd $args
    $exitCode = $LASTEXITCODE
} else {
    Write-UserMessage -Message "scoop: '$cmd' isn't a scoop command. See 'scoop help'." -Output
    $exitCode = 2
}

exit $exitCode
