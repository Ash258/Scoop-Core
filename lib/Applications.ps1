'core', 'json', 'Helpers', 'manifest', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

#region Application instalaltion info file
function Get-InstalledApplicationInformation {
    <#
    .SYNOPSIS
        Get stored information about installed application.
    .PARAMETER AppName
        Specifies the application name.
    .PARAMETER Version
        Specifies the version of the application.
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

    process {
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
                return $null
            }
        }

        return parse_json $installInfoPath
    }
}

function Get-InstalledApplicationInformationPropertyValue {
    <#
    .SYNOPSIS
        Get specific property stored in application's information file.
    .PARAMETER AppName
        Specifies the application name.
    .PARAMETER Version
        Specifies the version of the application.
        Use 'CURRENT_' to lookup for the currently used version. (Respecting NO_JUNCTION and different version)
    .PARAMETER Global
        Specifies globally installed application.
    .PARAMETER Property
        Specifies the property name to be evaluated.
    .PARAMETER InputObject
        Specifies the installation information object to be fed instead of loading it from file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $AppName,
        [String] $Version = 'CURRENT_',
        [Switch] $Global,
        [Parameter(Mandatory)]
        [String] $Property,
        [Object] $InputObject
    )

    process {
        $info = if ($InputObject) { $InputObject } else { Get-InstalledApplicationInformation -AppName $AppName -Version $Version -Global:$Global }
        $prop = $null

        if ($info) {
            $properties = @($info | Get-Member -MemberType 'NoteProperty' | Select-Object -ExpandProperty 'Name')
            if ($properties -and $properties.Contains($Property)) { $prop = $info.$Property }
        }

        return $prop
    }
}

function Set-InstalledApplicationInformationPropertyValue {
    <#
    .SYNOPSIS
        Set specific property to be preserved in application's information file.
    .PARAMETER AppName
        Specifies the application name.
    .PARAMETER Version
        Specifies the version of application.
        Use 'CURRENT_' to lookup for the currently used version. (Respecting NO_JUNCTION and different version)
    .PARAMETER Global
        Specifies globally installed application.
    .PARAMETER Property
        Specifies the property name to be saved.
    .PARAMETER Value
        Specifies the value to be saved.
    .PARAMETER Force
        Specifies to override the value saved in the file.
    .PARAMETER InputObject
        Specifies to feed installation information object instead of loading it all the time from file.
    .PARAMETER PassThru
        Specifies to return the new object from the function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $AppName,
        [String] $Version = 'CURRENT_',
        [Switch] $Global,
        [Parameter(Mandatory)]
        [String[]] $Property,
        [Parameter(Mandatory)]
        [Object[]] $Value,
        [Switch] $Force,
        [Object] $InputObject,
        [Switch] $PassThru
    )

    begin {
        if ($Version -ceq 'CURRENT_') { $Version = Select-CurrentVersion -AppName $AppName -Global:$Global }
        $info = if ($InputObject) { $InputObject } else { Get-InstalledApplicationInformation -AppName $AppName -Version $Version -Global:$Global }
        if (!$info) { $info = @{ } }
        if ($Property.Count -ne $Value.Count) {
            throw [ScoopException] 'Property and value mismatch'
        }
    }

    process {
        for ($i = 0; $i -lt $Property.Count; ++$i) {
            $prop = $Property[$i]
            $val = $Value[$i]
            $properties = @($info | Get-Member -MemberType 'NoteProperty' | Select-Object -ExpandProperty 'Name')

            if ($properties -and $properties.Contains($prop)) {
                if ($Force) {
                    $info.$prop = $val
                } else {
                    throw [ScoopException] "Property '$prop' is already set"
                }
            } else {
                $info | Add-Member -MemberType 'NoteProperty' -Name $prop -Value $val
            }
        }
    }

    end {
        $appDirectory = versiondir $AppName $Version $Global
        # TODO: Trim nulls
        # TODO: Out-InstalledApplicationInfoFile
        $info | ConvertToPrettyJson | Out-UTF8File -Path (Join-Path $appDirectory 'scoop-install.json')

        if ($PassThru) { return $info }
    }
}
#endregion Application instalaltion info file
