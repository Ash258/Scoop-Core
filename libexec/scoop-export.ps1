# Usage: scoop export [<OPTIONS>]
# Summary: Export (an importable) list of installed applications.
#
# Options:
#   -h, --help      Show help for this command.

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('buckets', 'Get-KnownBucket'),
    @('manifest', 'Resolve-ManifestInformation'),
    @('Versions', 'Clear-InstalledVersion')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")    }
}

<#
TODO: Export:
{
    "applications": [
        {
            "name": "xxx",
            "version": "xxxx",
            "bucket": "xxx",
            "url": "xxx",
            "architecture": "xxx",
            "global": false|true,
            "installedVersions": [
                "xxx",
                ...
            ]
        },
        {...},
        ...
    ],
    "buckets": [
        {
            "name": "xxx",
            "url": "xxx"
        }
    ],
    "config": {
        ...wholeConfig
    },
    "aliases": {
        "name": "xxx",
        "body": [
            "xxx"
        ]
    },
    environments??
}
#>

$ExitCode = 0
$Options, $null, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop export: $_err" -ExitCode 2 }

$local = installed_apps $false | ForEach-Object { @{ 'name' = $_; 'global' = $false } }
$global = installed_apps $true | ForEach-Object { @{ 'name' = $_; 'global' = $true } }

$Applications = @($local) + @($global)

# TODO: What to do?
if (!$Applications) { exit $ExitCode }

# Export applications
$Applications | Sort-Object -Property 'Name' | ForEach-Object {
    $app = $_.name
    $global = $_.global
    $ver = Select-CurrentVersion -AppName $app -Global:$global
    $globalDisplay = if ($global) { ' *global*' } else { $null }
    $installInfo = install_info $app $ver $global
    $bucket = ''

    if ($installInfo.bucket) {
        $bucket = ' [' + $installInfo.bucket + ']'
    } elseif ($installInfo.url) {
        $bucket = ' [' + $installInfo.url + ']'
    }

    if ($installInfo.architecture -and ((default_architecture) -ne $installInfo.architecture)) {
        $arch = ' {' + $installInfo.architecture + '}'
    } else {
        $arch = ''
    }

    Write-UserMessage -Message "$app (v:$ver)$globalDisplay$bucket$arch" -Output
}

exit $ExitCode
