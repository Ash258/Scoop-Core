'core', 'commands', 'help', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

$ALIAS_CMD_ALIAS = 'alias'

function Get-AliasesFromConfig {
    <#
    .SYNOPSIS
        Get hahstable of all aliases defined in config.
    #>
    return get_config $ALIAS_CMD_ALIAS ([PsCustomObject] @{ })
}

function Get-ScoopAliasPath {
    <#
    .SYNOPSIS
        Get fullpath to the executable file of registered alias.
    .PARAMETER AliasName
        Specifies the name of the alias.
    .OUTPUTS
        [System.String]
            Path to the alias executable.
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'Alias')]
        [AllowEmptyString()]
        [AllowNull()]
        [String] $AliasName
    )

    begin {
        if (($null -eq $AliasName) -or ($AliasName -eq '')) { throw [ScoopException] 'Alias name required' }
    }

    process { return shimdir $false | Join-Path -ChildPath "scoop-$AliasName.ps1" }
}

function Add-ScoopAlias {
    <#
    .SYNOPSIS
        Create the new alias.
    .PARAMETER Name
        Specifies the name of alias
    .PARAMETER Command
        Specifies the command invoked as soon as alias is called.
    .PARAMETER Description
        Specifies the description of the new script.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [String] $Name,
        [AllowEmptyString()]
        [String] $Command,
        [AllowEmptyString()]
        [String] $Description
    )

    if (!$Name) { throw 'Alias name is required' }
    if (!$Command) { throw 'Cannot create and empty alias' }

    $aliases = Get-AliasesFromConfig
    $shimDir = shimdir $false
    $aliasFileName = "scoop-$Name"

    if ($aliases.$Name) { throw "Alias $Name already exists" }

    Join-Path $shimDir "$aliasFileName.ps1" | Out-UTF8Content -Content @"
# Summary: $Description
$Command
"@

    # Add alias to config
    $aliases | Add-Member -Name $Name -Value $aliasFileName -MemberType 'NoteProperty'

    set_config $ALIAS_CMD_ALIAS $aliases | Out-Null
}

function Remove-ScoopAlias {
    <#
    .SYNOPSIS
        Remove configured alias.
    .PARAMETER Name
        Specifies the name of alias to be removed.
    #>
    [CmdletBinding()]
    param([String] $Name)

    if (!$Name) { throw 'Please specify which alias should be removed' }

    $aliases = Get-AliasesFromConfig
    if ($aliases.$Name) {
        Write-UserMessage -Message "Removing alias $Name..."

        rm_shim $aliases.$Name (shimdir $false)

        $aliases.PSObject.Properties.Remove($Name)
        set_config $ALIAS_CMD_ALIAS $aliases | Out-Null
    } else {
        throw "Alias $Name does not exist"
    }
}

function Get-ScoopAlias {
    param([Switch] $Verbose)
    $aliases = @()

    $props = @((Get-AliasesFromConfig).PSObject.Properties | Where-Object -Property 'MemberType' -EQ -Value 'NoteProperty')
    if ($props.Count -eq 0) { $props = @() }

    $props.GetEnumerator() | ForEach-Object {
        $content = Get-Content (command_path $_.Name)
        $cmd = ($content | Select-Object -Skip 1).Trim()
        $sum = (summary $content).Trim()

        $aliases += New-Object psobject -Property @{ 'Name' = $_.Name; 'Summary' = $sum; 'Command' = $cmd }
    }

    if ($aliases.Count -eq 0) { Write-UserMessage -Message 'No aliases defined' -Warning }

    return $aliases.GetEnumerator() | Sort-Object Name | Format-Table -Property 'Name', 'Summary', 'Command' -AutoSize -Wrap -HideTableHeaders:(!$Verbose)
}
