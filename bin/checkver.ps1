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
.PARAMETER Update
    Specifies to write updated manifest into file.
.PARAMETER ForceUpdate
    Specifies to write given manifest(s) even when there is no new version.
    Useful for hash updates or formating.
.PARAMETER SkipUpdated
    Specifies to not show up-to-date manifests.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1
    Check all manifest inside default directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -SkipUpdated
    Check all manifest inside default directory (list only outdated manifests).
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -Update
    Check all manifests and update All outdated manifests.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP
    Check manifest APP.json inside default directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -Update
    Check manifest APP.json and update, if there is newer version.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -ForceUpdate
    Check manifest APP.json and update, even if there is no new version.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP -Update -Version VER
    Check manifest APP.json and update, using version VER
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP DIR
    Check manifest APP.json inside ./DIR directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 -Dir DIR
    Check all manifests inside ./DIR directory.
.EXAMPLE
    PS BUCKETROOT > .\bin\checkver.ps1 APP DIR -Update
    Check manifest APP.json inside ./DIR directory and update if there is newer version.
#>
param(
    [SupportsWildcards()]
    [String] $App = '*',
    [Parameter(Mandatory)]
    [ValidateScript( {
            if (!(Test-Path $_ -Type 'Container')) { throw "$_ is not a directory!" }
            $true
        })]
    [String] $Dir,
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipUpdated,
    [String] $Version = ''
)

'core', 'manifest', 'buckets', 'autoupdate', 'json', 'Versions', 'install' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

$ForceUpdate | Out-Null # PowerShell/PSScriptAnalyzer#1472
$SkipUpdated | Out-Null # PowerShell/PSScriptAnalyzer#1472
$Update | Out-Null # PowerShell/PSScriptAnalyzer#1472
$Version | Out-Null # PowerShell/PSScriptAnalyzer#1472

$Dir = Resolve-Path $Dir
$Search = $App
$Queue = @()
$UNIVERSAL_REGEX = '[vV]?([\d.]+)'
$GITHUB_REGEX = "/releases/tag/$UNIVERSAL_REGEX"
$GH_TOKEN = $env:GITHUB_TOKEN
$cfToken = get_config 'githubToken'
if ($cfToken) { $GH_TOKEN = $cfToken }
$exitCode = 0
$problems = 0

#region Functions
function next($AppName, $Err) {
    Write-Host "${AppName}: " -NoNewline
    Write-UserMessage -Message $Err -Color 'DarkRed'

    # Just throw something to invoke try-catch
    throw 'error'
}

function Invoke-Check {
    param([Parameter(Mandatory)] [System.Management.Automation.PSEventArgs] $EventToCheck)

    $state = $EventToCheck.SourceEventArgs.UserState

    $gci = $state.gci
    $appName = $state.app
    $json = $state.json
    $url = $state.url
    $regexp = $state.regex
    $jsonpath = $state.jsonpath
    $xpath = $state.xpath
    $reverse = $state.reverse
    $replace = $state.replace
    $expectedVersion = $json.version
    $ver = ''

    $page = $EventToCheck.SourceEventArgs.Result
    $err = $EventToCheck.SourceEventArgs.Error

    if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-page.html' | Out-UTF8Content -Content $page }
    if ($json.checkver.script) {
        $page = $json.checkver.script -join "`r`n" | Invoke-Expression
        if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-page-script.html' | Out-UTF8Content -Content $page }
    }

    if ($err) {
        debug $state.url
        debug $state.regex
        debug $state.reverse
        debug $state.replace

        next $appName "$($err.Message)`r`nURL $url is not valid"
    }
    if (!$regex -and $replace) { next $appName "'replace' requires 'regex'" }

    if ($jsonpath) {
        # TODO: Refactor Json-Path
        $ver = json_path $page $jsonpath
        if (!$ver) { $ver = json_path_legacy $page $jsonpath }
        if (!$ver) {
            next $appName "could not find '$jsonpath' in $url"
        }
    }

    if ($xpath) {
        $xml = [xml] $page
        # Find all `significant namespace declarations` from the XML file
        $nsList = $xml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]')
        # Add them into the NamespaceManager
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)

        $nsList | ForEach-Object { $nsmgr.AddNamespace($_.LocalName, $_.Value) }
        # Getting version from XML, using XPath
        $ver = $xml.SelectSingleNode($xpath, $nsmgr).'#text'
        if (!$ver) { next $appName "could not find '$xpath' in $url" }
    }

    if ($jsonpath -and $regexp) {
        $page = $ver
        $ver = ''
    }
    if ($xpath -and $regexp) {
        $page = $ver
        $ver = ''
    }

    if ($regexp) {
        try {
            $regex = New-Object System.Text.RegularExpressions.Regex($regexp)
        } catch {
            next $appName $_.Exception.Message
        }

        $selectSplat = if ($reverse) { @{ 'Last' = 1 } } else { @{ 'First' = 1 } }
        $match = $regex.Matches($page) | Select-Object @selectSplat

        if ($match -and $match.Success) {
            $matchesHashtable = @{ }
            $regex.GetGroupNames() | ForEach-Object { $matchesHashtable.Add($_, $match.Groups[$_].Value) }
            $ver = $matchesHashtable['1']
            if ($replace) { $ver = $regex.Replace($match.Value, $replace) }
            if (!$ver) { $ver = $matchesHashtable['version'] }
        } else {
            next $appName "could not match '$regexp' in $url"
        }
    }

    if (!$ver) { next $appName "could not find new version in $url" }

    # Skip actual only if versions are same and there is no -f
    if (($ver -eq $expectedVersion) -and !$ForceUpdate -and $SkipUpdated) { return }

    Write-Host "${appName}: " -NoNewline

    # version hasn't changed (step over if forced update)
    if ($ver -eq $expectedVersion -and !$ForceUpdate) {
        Write-UserMessage -Message $ver -Color 'DarkGreen'
        return
    }

    Write-Host $ver -ForegroundColor 'DarkRed' -NoNewline
    Write-Host " (scoop version is $expectedVersion)" -NoNewline
    $updateAvailable = (Compare-Version -ReferenceVersion $expectedVersion -DifferenceVersion $ver) -ne 0

    if ($json.autoupdate -and $updateAvailable) {
        Write-UserMessage -Message ' autoupdate available' -Color 'Cyan'
    } else {
        Write-UserMessage -Message ''
    }

    # Forcing an update implies updating
    if ($ForceUpdate) {
        $Update = $true
    } elseif ($Update -and ($json.autoupdate.disable -and ($json.autoupdate.disable -eq $true))) {
        Write-UserMessage "${appName}: Skipping disabled autoupdate" -Info
        return
    }

    if ($Update -and $json.autoupdate) {
        if ($ForceUpdate) { Write-UserMessage -Message 'Forcing autoupdate!' -Color 'DarkMagenta' }
        if ($Version -ne '') { $ver = $Version }

        try {
            $newManifest = Invoke-Autoupdate $appName $Dir $json $ver $matchesHashtable -Extension $gci.Extension
            if ($null -eq $newManifest) { throw "Could not update $appname" }

            Write-UserMessage -Message "Writing updated $appName manifest" -Color 'DarkGreen'
            ConvertTo-Manifest -Path $gci.FullName -Manifest $newManifest
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
            throw 'Trigger problem detection'
        }
    }
}
#endregion Functions

# Clear any existing events
Get-Event | ForEach-Object { Remove-Event $_.SourceIdentifier }

#region Main
foreach ($ff in Get-ChildItem $Dir "$Search.*" -File) {
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
    if ($m.checkver) {
        if (!$ForceUpdate -and ($m.checkver.disable -and ($m.checkver.disable -eq $true))) {
            Write-UserMessage "$($ff.BaseName): Skipping disabled checkver" -Info
            continue
        }
        $Queue += , @($ff, $m)
    }
}

foreach ($q in $Queue) {
    $gci, $json = $q
    $name = $gci.Name
    $problemOccured = $false # Partially prevent duplicating problems

    $substitutions = Get-VersionSubstitution -Version $json.version

    $wc = New-Object System.Net.Webclient
    $ua = $json.checkver.useragent
    $ua = if ($ua) { Invoke-VariableSubstitution -Entity $ua -Substitutes $substitutions } else { Get-UserAgent }
    $wc.Headers.Add('User-Agent', $ua)

    Register-ObjectEvent $wc DownloadStringCompleted -ErrorAction Stop | Out-Null

    $url = $json.homepage
    $regex = ''
    $jsonpath = ''
    $xpath = ''
    $replace = ''
    $reverse = $json.checkver.reverse -and $json.checkver.reverse -eq 'true'
    $useGithubAPI = $false

    if ($json.checkver.url) { $url = $json.checkver.url }

    if ($json.checkver -eq 'github') {
        if (!$json.homepage.StartsWith('https://github.com/')) {
            Write-UserMessage -Message "$name checkver expects the homepage to be a github repository" -Err
            $problemOccured = $true
        }
        $url = $json.homepage.TrimEnd('/') + '/releases/latest'
        $regex = $GITHUB_REGEX
        $useGithubAPI = $true
    }
    if ($json.checkver.github) {
        $url = $json.checkver.github.TrimEnd('/') + '/releases/latest'
        $regex = $GITHUB_REGEX
        # TODO: See if this could be used allways
        if ($json.checkver.PSObject.Properties.Count -eq 1) { $useGithubAPI = $true }
    }

    if ($json.checkver.re) {
        Write-UserMessage -Message "${name}: 're' is deprecated. Use 'regex' instead" -Err
        $problemOccured = $true
        $regex = $json.checkver.re
    }
    if ($json.checkver.jp) {
        Write-UserMessage -Message "${name}: 'jp' is deprecated. Use 'jsonpath' instead" -Err
        $problemOccured = $true
        $jsonpath = $json.checkver.jp
    }

    if ($json.checkver.regex) { $regex = $json.checkver.regex }
    if ($json.checkver.jsonpath) { $jsonpath = $json.checkver.jsonpath }
    if ($json.checkver.xpath) { $xpath = $json.checkver.xpath }
    if ($json.checkver.replace -and $json.checkver.replace.GetType() -eq [System.String]) { $replace = $json.checkver.replace }
    if (!$jsonpath -and !$regex -and !$xpath) {
        $regex = if ($json.checkver -is [System.String]) { $json.checkver } else { $UNIVERSAL_REGEX }
    }

    if ($url -like '*api.github.com/*') { $useGithubAPI = $true }
    if ($useGithubAPI -and ($null -ne $GH_TOKEN)) {
        $url = $url -replace '//(www\.)?github.com/', '//api.github.com/repos/'
        $wc.Headers.Add('Authorization', "token $GH_TOKEN")
    }
    $url = Invoke-VariableSubstitution -Entity $url -Substitutes $substitutions

    $state = New-Object PSObject @{
        'app'      = (strip_ext $name)
        'url'      = $url
        'regex'    = $regex
        'json'     = $json
        'jsonpath' = $jsonpath
        'xpath'    = $xpath
        'reverse'  = $reverse
        'replace'  = $replace
        'gci'      = $gci
    }

    if ($problemOccured) { ++$problems }

    $wc.Headers.Add('Referer', (strip_filename $url))
    $wc.DownloadStringAsync($url, $state)
}

# Wait for all to complete
$inProgress = 0
while ($inProgress -lt $Queue.Length) {
    $ev = Wait-Event
    Remove-Event $ev.SourceIdentifier
    ++$inProgress

    try {
        Invoke-Check $ev
    } catch {
        ++$problems
        continue
    }
}

if ($problems -gt 0) { $exitCode = 10 + $problems }
exit $exitCode

#endregion Main
