'core', 'json', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

#region Application instalaltion info file
function Get-InstalledApplicationInformation {
    <#
    .SYNOPSIS
        Get stored information about installed application
    .PARAMETER AppName
        Specifies the application name.
    .PARAMETER Version
        Specifies version of application.
        Use 'CURRENT_' to lookup for the currently used version. (Respecting NO_JUNCTION and different version)
    .PARAMETER Global
        Specifies globally installed application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $AppName,
        [String] $Version = 'CURRENT_',
        [Switch] $Global
    )

    if ($Version -ceq 'CURRENT_') { $Version = Select-CurrentVersion -AppName $AppName -Global:$Global }
    $applicationDirectory = versiondir $AppName $Version $Global
    $installInfoPath = Join-Path $applicationDirectory 'scoop-install.json'

    if (!(Test-Path $installInfoPath)) {
        $old = Join-Path $applicationDirectory 'install.json'
        # Migrate from old scoop's 'install.json'
        if (Test-Path $old) {
            Write-UserMessage -Message 'Migrating ''install.json'' to ''scoop-install.json''' -Info
            Rename-Item $old 'scoop-install.json'
        } else {
            # TODO?: Throw
            return $null
        }
    }

    return parse_json $installInfoPath
}

function Set-InstalledApplicationInformationProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $AppName,
        [String] $Version = 'CURRENT_',
        [Switch] $Global,
        [String[]] $Property,
        [Object[]] $Value,
        [Switch] $Update
    )

    begin {
        $info = Get-InstalledApplicationInformation -AppName $AppName -Version $Version -Global:$Global
        if ($Version -ceq 'CURRENT_') { $Version = Select-CurrentVersion -AppName $AppName -Global:$Global }
        if (!$info) { $info = @{ } }
        if ($Property.Count -ne $Value.Count) {
            throw [ScoopException] "Property and value mismatch"
        }
    }

    process {
        for ($i = 0; $i -lt $Property.Count; ++$i) {
            $prop = $Property[$i]
            $val = $Value[$i]

            # TODO: Fix
            if ($info.$prop) {
                if ($Update) {
                    $info.$prop = $val
                } else {
                    Write-UserMessage -Message "Property '$prop' is already set" -Err
                }
            } else {
                $info | Add-Member -MemberType NoteProperty -Name $prop -Value $val
            }
        }
    }

    end {
        $appDirectory = versiondir $AppName $Version $Global
        $info | ConvertToPrettyJson | Out-UTF8File -Path (Join-Path $appDirectory 'scoop-install.json')
    }
}

function Get-InstalledApplicationInformationProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $AppName,
        [String] $Version = 'CURRENT_',
        [Switch] $Global,
        [String] $Property
    )

    $info = Get-InstalledApplicationInformation -AppName $AppName -Version $Version -Global:$Global
    if ($info -and $info.$Property) { return $info.$Property }

    return $null
}
#endregion Application instalaltion info file
