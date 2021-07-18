#Requires -Version 5
param([String] $Command)

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

$ExitCode = 0

# Powershell automatically bind bash like short parameters as $args, and does not put it in $Command parameter
# ONLY if:
# - No command passed
# - -v or --version passed
$version = ($Command -eq '--version') -or (!$Command -and ($args.Contains('-v')))

# Scoop itself help should be shown only if explicitly asked:
# - No version asked
# - No command passed
# - /?, /help,, /h, --help, -h passed
$scoopHelp = !$version -and (!$Command -or (($Command -in @($null, '--help', '/?', '/help', '/h')) -or (!$Command -and ($args.Contains('-h')))))

# Valid command execution
$validCommand = $Command -and ($Command -in (commands))

# Command help should be shown only if:
# - No help for scoop asked
# - $Command is passed
# - --help, -h is in $args
$commandHelp = !$scoopHelp -and $validCommand -and (($args.Contains('--help')) -or ($args.Contains('-h')))

if ($version) {
    Write-UserMessage -Output -Message @(
        "PowerShell version: $($PSVersionTable.PSVersion)"
        'Current Scoop (Shovel) version:'
    )
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
    $ExitCode = $LASTEXITCODE
} elseif ($commandHelp) {
    Invoke-ScoopCommand 'help' @($Command)
    $ExitCode = $LASTEXITCODE
} elseif ($validCommand) {
    Invoke-ScoopCommand $Command $args
    $ExitCode = $LASTEXITCODE
} else {
    Write-UserMessage -Message "scoop: '$Command' isn't a scoop command. See 'scoop help'." -Output
    $ExitCode = 2
}

exit $ExitCode
