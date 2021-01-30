# Usage: scoop utils [utility] [path] [options] [--additional-options ...]
# Summary: Wrapper around utilities for maintaining buckets and manifests.
# Help: Bucket maintainers no longer need to have own 'bin' folder and they can use native command instead.
#
# Two possible ways how to pass parameters to this command:
#     1. Pass fullname of the manifest. No wildcard supported
#     2. Pass simple string (with wildcard support) to search in ./bucket/ folder
#           Or pass --bucketdir to override default search path
#
# Options:
#   -b, --bucketdir         Use specific bucket directory instead of default './bucket/'.
#   --additional-options    Valid, powershell like parameters passed to specific utility binary.
#                               Refer to each utility for all availalbe parameters/options.
#   -h, --help              Show help for this command.
#
# Example usage:
#    'scoop utils checkver $env:SCOOP\buckets\main\bucket\pwsh.json' => Check explicitly passed manfiest files
#    'scoop utils checkver manifest*' => Check all manifests matching manifest* in ./bucket/
#    'scoop utils checkhashes manifest*' --bucketdir ..\..\testbucket\bucket => Check all manifests matching manifest* in provided directory
#    'scoop utils auto-pr --additional-options -Upstream "user/repo:branch" -skipcheckver -push' => Execute auto-pr with specific upstream string
#

'core', 'getopt', 'Git', 'Helpers', 'help' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$getopt = $args
$AdditionalArgs = @()
# Remove additional args before processing arguments
if ($args -contains '--additional-options') {
    $index = $args.IndexOf('--additional-options')
    $getopt = $args[0..($index - 1)]
    $AdditionalArgs = $args[($index + 1)..($args.Count - 1)]
}


#region Parameter validation
$opt, $rem, $err = getopt $getopt 'b:' 'bucketdir='
if ($err) { Stop-ScoopExecution -Message "scoop utils: $err" -ExitCode 1 -Usage (my_usage) }

$VALID_UTILITIES = @(
    'auto-pr'
    'checkhashes'
    'checkurl'
    'checkver'
    'describe'
    'format'
    'missing-checkver'
)
$Utility = $rem[0]
$ManifestPath = $rem[1]
$BucketFolder = Join-Path $PWD 'bucket'
if ($opt.b -or $opt.bucketdir) { $BucketFolder = $opt.b, $opt.bucketdir | Where-Object { $null -ne $_ } | Select-Object -First 1 }
try {
    $BucketFolder = Resolve-Path $BucketFolder -ErrorAction 'Stop'
} catch {
    Stop-ScoopExecution -Message "scoop utils: $BucketFolder is not valid directory" -ExitCode 2
}

if (!$Utility) { Stop-ScoopExecution -Message 'No utility provided' -ExitCode 1 -Usage (my_usage) }
if ($Utility -notin $VALID_UTILITIES) { Stop-ScoopExecution -Message "$Utility is not valid Scoop utility" -ExitCode 1 -Usage (my_usage) }
$UtilityPath = (Join-Path $PSScriptRoot '..\bin' | Get-ChildItem -Filter "$Utility.ps1" -File).FullName
#endregion Parameter validation

$exitCode = 0
# Fullpath parameter or nothing
if (!$ManifestPath) {
    $ManifestPath = '*'
} elseif (Test-Path -LiteralPath $ManifestPath -ErrorAction 'SilentlyContinue') {
    $item = Get-Item $ManifestPath
    $BucketFolder = $item.Directory.FullName
    $ManifestPath = $item.BaseName
}

$splatParameters = @{
    'Dir' = $BucketFolder
    'App' = $ManifestPath
}
# Automatically fill upstream in case of auto-pr and current folder is git repository root
if (($Utility -eq 'auto-pr') -and (Join-Path $PWD '.git' | Test-Path -PathType Container) -and (Test-CommandAvailable 'git')) {
    try {
        $remoteUrl = Invoke-GitCmd -Command 'config' -Repository $BucketFolder -Argument @('--get', 'remote.origin.url')
    } catch {
        Stop-ScoopExecution -Message 'Cannot automatically determine upstream parameter. Use ''--additional-options -upstream <upstream>'''
    }
    $splatParameters.Add('Upstream', ($remoteUrl -replace '^.+[:/](?<user>.*)/(?<repo>.*?)(\.git)?$', '${user}/${repo}:master')) # TODO: Main adoption
}

try {
    & $UtilityPath @splatParameters @AdditionalArgs
    $exitCode = $LASTEXITCODE
} catch {
    Write-UserMessage -Message "Utility issue: $($_.Exception.Message)" -Err
    $exitCode = 3
}

exit $exitCode
