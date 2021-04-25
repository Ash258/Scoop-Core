# Usage: scoop utils <UTILITY> [<OPTIONS>] [<PATH>] [--additional-options <OPTS>...]
# Summary: Wrapper around utilities for maintaining buckets and manifests.
# Help: Bucket maintainers do need to have own 'bin' folder and they can use native command.
#
# There are two possible ways how to pass parameters to this command:
#     1. Pass fullname of the manifest. This will check explicitly the provided path with no wildcard support.
#     2. Pass simple string (with wildcard support) to search in ./bucket/ folder.
#           Or pass --bucketdir to override default bucket path.
#
# Options:
#   -h, --help              Show help for this command.
#   -b, --bucketdir         Use specific bucket directory instead of default './bucket/'.
#   --additional-options    Valid, powershell-like parameters passed to specific utility binary.
#                               Refer to each utility for all available parameters/options.
#
# Example usage:
#    'scoop utils checkver $env:SCOOP\buckets\main\bucket\pwsh.json' => Check explicitly passed manfiest files
#    'scoop utils checkver manifest*' => Check all manifests matching manifest* in ./bucket/
#    'scoop utils checkhashes manifest*' --bucketdir ..\..\testbucket\bucket => Check all manifests matching manifest* in provided directory
#    'scoop utils auto-pr --additional-options -Upstream "user/repo:branch" -Skipcheckver -Push' => Execute auto-pr utility with specific upstream string

'core', 'getopt', 'Helpers', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$getopt = $args
$AdditionalArgs = @()
# Remove additional args before processing arguments
if ($args -contains '--additional-options') {
    $index = $args.IndexOf('--additional-options')
    $getopt = $args[0..($index - 1)] # Everything before --additional-options is considered as wrapper command options.
    $AdditionalArgs = $args[($index + 1)..($args.Count - 1)] # Everything after is considered as utility-specific option.
}

#region Parameter handling/validation
$Opt, $Rem, $err = getopt $getopt 'b:' 'bucketdir='
if ($err) { Stop-ScoopExecution -Message "scoop utils: $err" -ExitCode 1 -Usage (my_usage) }

$Utility = $Rem[0]
$VALID_UTILITIES = @(
    'auto-pr'
    'checkhashes'
    'checkurls'
    'checkver'
    'describe'
    'format'
    'missing-checkver'
)

if (!$Utility) { Stop-ScoopExecution -Message 'Parameter <UTILITY> missing' -ExitCode 1 -Usage (my_usage) }
if ($Utility -notin $VALID_UTILITIES) { Stop-ScoopExecution -Message "'$Utility' is not valid scoop utility" -ExitCode 1 -Usage (my_usage) }

$UtilityPath = (Join-Path $PSScriptRoot '..\bin' | Get-ChildItem -Filter "$Utility.ps1" -File).FullName
$BucketFolder = Join-Path $PWD 'bucket'
$ManifestPath = $Rem[1]

if ($Opt.b -or $Opt.bucketdir) { $BucketFolder = $Opt.b, $Opt.bucketdir | Where-Object { $null -ne $_ } | Select-Object -First 1 }

# Edge case for fullpath or nothing, which needs special handling.
if (!$ManifestPath) {
    $ManifestPath = '*'
} elseif (Test-Path -LiteralPath $ManifestPath) {
    $item = Get-Item -LiteralPath $ManifestPath
    $BucketFolder = $item.Directory.FullName
    $ManifestPath = $item.BaseName
}

try {
    $BucketFolder = Resolve-Path $BucketFolder -ErrorAction 'Stop'
} catch {
    Stop-ScoopExecution -Message "scoop utils: '$BucketFolder' is not valid directory" -ExitCode 2
}
#endregion Parameter handling/validation

$ExitCode = 0

try {
    & $UtilityPath -App $ManifestPath -Dir $BucketFolder @AdditionalArgs
    $ExitCode = $LASTEXITCODE
} catch {
    Write-UserMessage -Message "Utility issue: $($_.Exception.Message)" -Err
    $ExitCode = 3
}

exit $ExitCode
