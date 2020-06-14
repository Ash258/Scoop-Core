Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
(7z.exe | Select-String -Pattern '7-Zip').ToString()
Write-Host 'Installing dependencies ...'
Install-Module -Name Pester -Repository PSGallery -Scope CurrentUser -SkipPublisherCheck -Force
Install-Module -Name PSScriptAnalyzer, BuildHelpers -Repository PSGallery -Scope CurrentUser -Force

if ($env:CI_WINDOWS -eq $true) {
    # Do not force maintainers to have this inside environment appveyor config
    if (-not $env:SCOOP_HELPERS) {
        $env:SCOOP_HELPERS = 'C:\projects\helpers'
        [System.Environment]::SetEnvironmentVariable('SCOOP_HELPERS', $env:SCOOP_HELPERS, 'Machine')
    }
    if (!(Test-Path $env:SCOOP_HELPERS)) { New-Item -Path $env:SCOOP_HELPERS -ItemType Directory | Out-Null }

    if (!(Test-Path "$env:SCOOP_HELPERS\lessmsi\lessmsi.exe")) {
        Write-Warning 'Installing lessmsi'
        Start-FileDownload 'https://github.com/activescott/lessmsi/releases/download/v1.6.3/lessmsi-v1.6.3.zip' -FileName "$env:SCOOP_HELPERS\lessmsi.zip"
        & 7z.exe x "$env:SCOOP_HELPERS\lessmsi.zip" -o"$env:SCOOP_HELPERS\lessmsi" -y
    }
    if (!(Test-Path "$env:SCOOP_HELPERS\innounp\innounp.exe")) {
        Write-Warning 'Installing innounp'
        Start-FileDownload 'https://raw.githubusercontent.com/ScoopInstaller/Binary/master/innounp/innounp048.rar' -FileName "$env:SCOOP_HELPERS\innounp.rar"
        & 7z.exe x "$env:SCOOP_HELPERS\innounp.rar" -o"$env:SCOOP_HELPERS\innounp" -y
    }

    'shims', 'workspace', 'persist', 'modules', 'cache', 'buckets' | ForEach-Object {
        New-Item (Join-Path $env:SCOOP $_) -ItemType Directory | Out-Null
    }

    Write-Warning 'Downloading main bucket'
    Start-FileDownload 'https://github.com/ScoopInstaller/Main/archive/master.zip' -FileName "$env:SCOOP\buckets\main.zip"
    & 7z.exe x "$env:SCOOP\buckets\main.zip" -o"$env:SCOOP\buckets\main" -y
}

if ($env:CI -and ($env:CI -eq $true)) {
    Write-Host 'Load ''BuildHelpers'' environment variables ...'
    Set-BuildEnvironment -Force
}

$buildVariables = Get-ChildItem -Path 'Env:' | Where-Object -Property Name -Match '(?:BH|CI(?:_|$)|APPVEYOR)'
$buildVariables = $buildVariables, (Get-Variable -Name 'CI_*' -Scope 'Script')
$details = $buildVariables |
    Where-Object -Property Name -NotMatch 'EMAIL' |
    Sort-Object -Property 'Name' |
    Format-Table -AutoSize -Property 'Name', 'Value' |
    Out-String
Write-Host 'CI variables:'
Write-Host $details -ForegroundColor DarkGray
