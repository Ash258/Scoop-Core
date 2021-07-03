<#
.SYNOPSIS
    Check manifest for a newer version.
.DESCRIPTION
    Checks websites for newer versions using an (optional) regular expression defined in the manifest.
.PARAMETER App
    Specifies the manifest name.
    Wildcards are supported.
.PARAMETER Dir
    Specifies the location of manifests.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir
)

'core', 'manifest', 'buckets', 'autoupdate', 'json', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$Dir = Resolve-Path $Dir
$Queue = @()
$exitCode = 0
$problems = 0

Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
$validator = New-Object Scoop.Validator("$PSScriptRoot\..\schema.json", $false)
$quotaExceeded = $false
$All = @{}

foreach ($ff in Get-ChildItem $Dir "$App.*" -File) {
    if ($ff.Extension -notmatch "\.($ALLOWED_MANIFEST_EXTENSION_REGEX)") {
        Write-UserMessage "Skipping $($ff.Name)" -Info
        continue
    }

    try {
        $m = ConvertFrom-Manifest -Path $ff.FullName
    } catch {
        Write-UserMessage -Message "Invalid manifest: $($ff.Name)" -Err
        ++$problems
        continue
    }

    $checks = @{}

    # TODO: Support YAML
    # Schema validation
    if (!$quotaExceeded -and ($ff.Extension -notmatch '\.ya?ml$')) {
        try {
            $result = $validator.Validate($ff.FullName)
            $checks.Add('Schema', $result)
        } catch {
            if ($_.Exception.Message -like '*The free-quota limit of 1000 schema validations per hour has been reached.*') {
                $quotaExceeded = $true
                Write-UserMessage -Message 'Schema validation limit exceeded. Will skip further validations.' -Color 'DarkYellow'
            } else {
                throw
            }
        }
    }

    $licenseCheck = ([bool] $m.license)
    if ($m.license -is [String]) {
        # TODO: Test URL from spdx
    } elseif ($m.license.identifier) {
        if ($m.license.url) {
            $licenseCheck = $true
        } else {
            # TODO: Test string identifier as above
        }
    }
    $checks.Add('License', $licenseCheck)

    # URLS + Hashes Invoke-ScoopCommand 'download' -b $_
    # Scripts
    #   Replace deprecated functions
    #   ??Try with code style??
    # Checkver
    # Autoupdate
    # Installation
    # Update
    # Uninstallation
    # Format
    $All.Add($ff.BaseName, $checks)
}

if ($problems -gt 0) { $exitCode = 10 + $problems }

$All | ConvertTo-Json | Write-Host -f green

exit $exitCode
