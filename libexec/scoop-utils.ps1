# Usage: scoop utils [utility] [path] [options] [args]
# Summary: Wrapper around utilities for maintaining buckets and manifests.
# Help: Bucket maintainers no longer need to have own 'bin' folder and they can use native command instead.
#
# Fullpath should always point to only 1 file. If should be passed
#
# Utilities - Arguments available:
#   auto-pr             -
#   checkhashes         -
#   checkurl            -
#   checkver            -
#   describe            -
#   format              -
#   missing-checkver    -

param([String] $Utility, [String] $Path)

$baseFolder = $PWD
$localBucket = Join-Path $baseFolder 'bucket'
if (Test-Path $localBucket -PathType Container) { $baseFolder = $localBucket }

if (!$Path) { $Path = '*' }
# Determine if fullpath was passed
# If passed string could be found in local bucket it should be used
if (Join-Path $baseFolder "$Path*" | Test-Path) {
    $app = $Path
} elseif (Test-Path $Path) {
    # Fullpath passed
    $it = Get-Item $Path
    $useForEach = $it.Count -gt 1
    $app = $it.BaseName
    $baseFolder = $it.Directory
}

$ut = Join-Path $PSScriptRoot '..\bin' | Get-ChildItem -Filter "$Utility*.ps1"

if ($useForEach) {
    Write-Host 'here'
    $it | ForEach-Object {
        & "$($ut.FullName)" -App $_.BaseName() -Dir $_.Directory @args
    }
} else {
    & "$($ut.FullName)" -App $app -Dir $baseFolder @args
}
$exitCode = $LASTEXITCODE

exit $exitCode
