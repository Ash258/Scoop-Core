#Requires -Version 5.0
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '4.4.0' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }

param([String] $TestPath = 'test/')

$splat = @{
    CI   = $true
    Path = $TestPath
}

if ($env:CI -and ($env:CI -eq $true)) {
    $excludes = @()
    $commit = if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT) { $env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT } else { $env:APPVEYOR_REPO_COMMIT }
    $commitMessage = "$env:APPVEYOR_REPO_COMMIT_MESSAGE $env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED".TrimEnd()
    $commitChangedFiles = @(Get-GitChangedFile -Commit $commit -Exclude 'supporting*' )

    if ($commitMessage -match '!linter') {
        Write-Warning 'Skipping code linting per commit flag ''!linter'''
        $excludes += 'Linter'
    }

    if (($commitChangedFiles -match '\.ps(m|d)?1$').Count -eq 0) {
        Write-Warning 'Skipping tests and code linting for *.ps1 files because they did not change'
        $excludes += 'Linter'
        $excludes += 'Scoop'
    }

    if (($commitChangedFiles -match 'decompress\.ps(m|d)?1$').Count -eq 0) {
        Write-Warning 'Skipping tests and code linting for decompress.ps1 files because it did not change'
        $excludes += 'Decompress'
    }

    if ($env:CI_WINDOWS -and ($env:CI_WINDOWS -ne $true)) {
        Write-Warning 'Skipping tests and code linting for decompress.ps1 because they only work on Windows'
        $excludes += 'Decompress'
    }

    if ($commitMessage -match '!manifests') {
        Write-Warning 'Skipping manifest validation per commit flag ''!manifests'''
        $excludes += 'Manifests'
    }

    $json = $commitChangedFiles -match '\.json$'
    $json = $json -notmatch '\.vscode|schema|buckets|supporting'
    if ($json.Count -eq 0) {
        Write-Warning 'Skipping tests and validation for manifest files because they did not change'
        $excludes += 'Manifests'
    }

    if ($excludes.Length -gt 0) { $splat.ExcludeTag = $excludes }
    if ($commitChangedFiles.Count -eq 0) {
        Write-Warning 'No changed files'
        exit 0
    }
}

Write-Host 'Invoke-Pester' @splat -ForegroundColor Magenta
Invoke-Pester @splat
