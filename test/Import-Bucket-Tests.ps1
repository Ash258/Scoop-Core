if ([String]::IsNullOrEmpty($MyInvocation.PSScriptRoot)) {
    Write-Error 'This script should not be called directly! It has to be imported from a buckets test file!'
    exit 1
}

. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

$repo_dir = (Get-Item $MyInvocation.PSScriptRoot).FullName

$repo_files = @(Get-ChildItem $repo_dir -File -Recurse)

$project_file_exclusions = @(
    $([regex]::Escape($repo_dir) + '(\\|/).git(\\|/).*$'),
    '.sublime-workspace$',
    '.DS_Store$',
    'supporting(\\|/)validator(\\|/)packages(\\|/)*'
)

$bucketdir = $repo_dir
if (Test-Path("$repo_dir\bucket")) {
    $bucketdir = "$repo_dir\bucket"
}

. "$PSScriptRoot\Import-File-Tests.ps1"
. "$PSScriptRoot\Scoop-Manifest.Tests.ps1" -bucketdir $bucketdir
