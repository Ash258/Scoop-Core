if (!((Get-Command 'scoop' -ErrorAction 'SilentlyContinue') -or (Get-Command 'shovel' -ErrorAction 'SilentlyContinue'))) {
    Write-Error 'Scoop is not installed'
    exit 1
}

$script:SCOOP_DIRECTORY = $env:SCOOP, "$env:USERPROFILE\scoop" | Where-Object { ![String]::IsNullOrEmpty($_) } | Select-Object -First 1
$script:SCOOP_GLOBAL_DIRECTORY = $env:SCOOP_GLOBAL, "$env:ProgramData\scoop" | Where-Object { ![String]::IsNullOrEmpty($_) } | Select-Object -First 1
$script:SCOOP_CACHE_DIRECTORY = $env:SCOOP_CACHE, "$SCOOP_DIRECTORY\cache" | Where-Object { ![String]::IsNullOrEmpty($_) } | Select-Object -First 1
$script:SCOOP_COMMANDS = @(
    'alias'
    'bucket'
    'cache'
    'cat'
    'checkup'
    'cleanup'
    'config'
    'depends'
    'download'
    'export'
    'help'
    'hold'
    'home'
    'info'
    'install'
    'list'
    'prefix'
    'reset'
    'search'
    'status'
    'unhold'
    'uninstall'
    'update'
    'utils'
    'virustotal'
    'which'
)
$script:SCOOP_SUB_COMMANDS = @{
    'alias'  = 'add list rm edit path'
    'bucket' = 'add known list rm'
    'cache'  = 'rm show'
    'config' = 'rm show'
    'utils'  = 'auto-pr checkhashes checkurls checkver describe format missing-checkver'
}
$script:SCOOP_SHORT_PARAMETERS = @{
    'cleanup'    = 'g k'
    'download'   = 's u a b'
    'hold'       = 'g'
    'install'    = 'g i k s a'
    'list'       = 'i u r'
    'search'     = 'r'
    'unhold'     = 'g'
    'uninstall'  = 'g p'
    'update'     = 'f g i k s q'
    'utils'      = 'b'
    'virustotal' = 'a s n'
}
$script:SCOOP_LONG_PARAMETERS = @{
    'cleanup'    = 'global cache'
    'download'   = 'skip utility arch all-architectures'
    'hold'       = 'global'
    'install'    = 'global independent no-cache skip arch'
    'list'       = 'installed updated reverse'
    'search'     = 'remote'
    'unhold'     = 'global'
    'uninstall'  = 'global purge'
    'update'     = 'force global independent no-cache skip quiet'
    'utils'      = 'bucketdir additional-options'
    'virustotal' = 'arch scan no-depends'
}
# Add --help and -h to all
# TODO: Investigate cleaner approach
foreach ($cmd in $SCOOP_COMMANDS) {
    if ($SCOOP_LONG_PARAMETERS.Keys -contains $cmd) {
        $SCOOP_LONG_PARAMETERS[$cmd] = $SCOOP_LONG_PARAMETERS[$cmd] + ' help'
    } else {
        $SCOOP_LONG_PARAMETERS.Add($cmd, 'help')
    }

    if ($SCOOP_SHORT_PARAMETERS.Keys -contains $cmd) {
        $SCOOP_SHORT_PARAMETERS[$cmd] = $SCOOP_SHORT_PARAMETERS[$cmd] + ' h'
    } else {
        $SCOOP_SHORT_PARAMETERS.Add($cmd, 'h')
    }
}

$script:SCOOP_PARAMETER_VALUES = @{
    'install'    = @{
        'a'    = '32bit 64bit'
        'arch' = '32bit 64bit'
    }
    'download'   = @{
        'a'       = '32bit 64bit'
        'arch'    = '32bit 64bit'
        'u'       = 'native aria2'
        'utility' = 'native aria2'
    }
    'virustotal' = @{
        'a'    = '32bit 64bit'
        'arch' = '32bit 64bit'
    }
}

$script:REGEX_SHORT_PARAMETERS = $SCOOP_SHORT_PARAMETERS.Keys -join '|'
$script:REGEX_LONG_PARAMETERS = $SCOOP_LONG_PARAMETERS.Keys -join '|'
$script:REGEX_PARAMETERS_VALUES = $SCOOP_PARAMETER_VALUES.Keys -join '|'

#region Helpers
function script:Expand-ScoopLongParameter($Cmd, $Filter) {
    return @($SCOOP_LONG_PARAMETERS[$Cmd] -split ' ') -like "$Filter*" | Sort-Object | ForEach-Object { "--$_" }
}

function script:Expand-ScoopShortParameter($Cmd, $Filter) {
    return @($SCOOP_SHORT_PARAMETERS[$Cmd] -split ' ') -like "$Filter*" | Sort-Object | ForEach-Object { "-$_" }
}

function script:Expand-ScoopParametersValue($Cmd, $Param, $Filter) {
    return @($SCOOP_PARAMETER_VALUES[$Cmd][$Param] -split ' ') -like "$Filter*" | Sort-Object
}

function script:Get-ScoopAlias($Filter) {
    $_config = scoop config show | ConvertFrom-Json
    $allAliases = $_config.'alias'
    $res = @()
    if ($null -ne $allAliases) {
        $res = @(@($allAliases.PSObject.Properties.Name) -like "$Filter*")
    }

    return $res
}

function script:New-AllScoopAlias {
    $al = @()

    'scoop', 'shovel' | ForEach-Object {
        $al += $_, "$_\.ps1", "$_\.cmd"
        $al += @(Get-Alias | Where-Object -Property 'Definition' -EQ -Value $_ | Select-Object -ExpandProperty 'Name')
    }

    return $al -join '|'
}

function script:Expand-ScoopCommandParameter($Commands, $Command, $Filter) {
    return @($Commands.$Command -split ' ') -like "$Filter*"
}

function script:Expand-ScoopCommand($Filter, [Switch] $IncludeAlias) {
    $cmdList = $SCOOP_COMMANDS
    if ($IncludeAlias) { $cmdList += Get-ScoopAlias($Filter) }

    return @($cmdList) -like "$Filter*" | Sort-Object
}

function script:Get-LocallyInstalledApplicationsByScoop($Filter) {
    $apps = @()
    $SCOOP_DIRECTORY, $SCOOP_GLOBAL_DIRECTORY | ForEach-Object {
        $apps += @(Get-ChildItem $_ 'apps\*' -Exclude 'scoop' -Directory -Name)
    }

    return @($apps | Select-Object -Unique) -like "$Filter*"
}

function script:Get-LocallyAvailableApplicationsByScoop($Filter) {
    $buckets = Get-ChildItem $SCOOP_DIRECTORY 'buckets\*' -Directory

    $manifests = @()
    foreach ($buc in $buckets) {
        $manifests += Get-ChildItem $buc.FullName 'bucket\*' -File | Select-Object -ExpandProperty 'BaseName'
    }

    return @($manifests | Select-Object -Unique) -like "$Filter*"
}

function script:Get-ScoopCachedFile($Filter) {
    if (!(Test-Path -LiteralPath $SCOOP_CACHE_DIRECTORY)) { return @() }

    $files = Get-ChildItem -Path "$SCOOP_CACHE_DIRECTORY\*#*" -File -Name
    $res = @()

    foreach ($f in $files) { $res += ($f -split '#')[0] }

    return @($res | Select-Object -Unique) -like "$Filter*"
}

function script:Get-LocallyAddedBucket($Filter) {
    return @(Get-ChildItem $SCOOP_DIRECTORY 'buckets\*' -Directory -Name) -like "$Filter*"
}

function script:Get-AvailableBucket($Filter) {
    return @(scoop bucket known) -like "$Filter*"
}
#endregion Helpers

function script:ScoopTabExpansion($LastBlock) {
    switch -Regex ($LastBlock) {
        # Handles Scoop <cmd> --<param> <value>
        "^(?<cmd>$REGEX_PARAMETERS_VALUES).* --(?<param>.+) (?<value>\w*)$" {
            if ($SCOOP_PARAMETER_VALUES[$Matches['cmd']][$Matches['param']]) {
                return Expand-ScoopParametersValue $Matches['cmd'] $Matches['param'] $Matches['value']
            }
        }

        # Handles Scoop <cmd> -<shortparam> <value>
        "^(?<cmd>$REGEX_PARAMETERS_VALUES).* -(?<param>.+) (?<value>\w*)$" {
            if ($SCOOP_PARAMETER_VALUES[$Matches['cmd']][$Matches['param']]) {
                return Expand-ScoopParametersValue $Matches['cmd'] $Matches['param'] $Matches['value']
            }
        }

        # Handles uninstall package names
        '^(cleanup|hold|prefix|reset|uninstall|update|unhold)\s+(?:.+\s+)?(?<package>[\w][\-.\w]*)?$' {
            return Get-LocallyInstalledApplicationsByScoop $Matches['package']
        }

        # Handles install package names
        '^(cat|depends|download|info|install|home|virustotal)\s+(?:.+\s+)?(?<package>[\w][\-.\w]*)?$' {
            return Get-LocallyAvailableApplicationsByScoop $Matches['package']
        }

        # Handles cache (rm/show) cache names
        '^cache (rm|show)\s+(?:.+\s+)?(?<cache>[\w][\-.\w]*)?$' {
            return Get-ScoopCachedFile $Matches['cache']
        }

        # Handles bucket rm bucket names
        '^bucket rm\s+(?:.+\s+)?(?<bucket>[\w][\-.\w]*)?$' {
            return Get-LocallyAddedBucket $Matches['bucket']
        }

        # Handles bucket add bucket names
        '^bucket add\s+(?:.+\s+)?(?<bucket>[\w][\-.\w]*)?$' {
            return Get-AvailableBucket $Matches['bucket']
        }

        # Handles alias rm|edit|path alias names
        '^alias (rm|edit|path)\s+(?:.+\s+)?(?<alias>[\w][\-\.\w]*)?$' {
            return Get-ScoopAlias $Matches['alias']
        }

        # Handles Scoop help <cmd>
        '^help (?<cmd>\S*)$' {
            return Expand-ScoopCommand $Matches['cmd']
        }

        # Handles Scoop <cmd> <subcmd>
        "^(?<cmd>$($SCOOP_SUB_COMMANDS.Keys -join '|'))\s+(?<op>\S*)$" {
            return Expand-ScoopCommandParameter $SCOOP_SUB_COMMANDS $Matches['cmd'] $Matches['op']
        }

        # Handles Scoop <cmd>
        '^(?<cmd>\S*)$' {
            return Expand-ScoopCommand $Matches['cmd'] -IncludeAlias
        }

        # Handles Scoop <cmd> --<param>
        "^(?<cmd>$REGEX_LONG_PARAMETERS).* --(?<param>\S*)$" {
            return Expand-ScoopLongParameter $Matches['cmd'] $Matches['param']
        }

        # Handles Scoop <cmd> -<shortparam>
        "^(?<cmd>$REGEX_SHORT_PARAMETERS).* -(?<shortparam>\S*)$" {
            return Expand-ScoopShortParameter $Matches['cmd'] $Matches['shortparam']
        }
    }
}

# Rename already hooked TabExpansion
if (Test-Path Function:\TabExpansion) { Rename-Item Function:\TabExpansion TabExpansion_Scoop_Backup }

function TabExpansion($Line, $LastWord) {
    <#
    .SYNOPSIS
        Handle tab completion of all scoop|shovel commands
    #>
    $lastBlock = [Regex]::Split($Line, '([|;]|[&|]{2})')[-1].TrimStart()

    switch -Regex ($lastBlock) {
        # https://regex101.com/r/COrwSO
        "^(sudo\s+)?((\.[\\\/])?bin[\\\/])?(($(New-AllScoopAlias)))\s+(?<rest>.*)$" { ScoopTabExpansion $Matches['rest'] }

        default { if (Test-Path Function:\TabExpansion_Scoop_Backup) { TabExpansion_Scoop_Backup $Line $LastWord } }
    }
}

Export-ModuleMember -Function 'TabExpansion'
