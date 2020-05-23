<#
.SYNOPSIS
    Check manifest for a newer version.
.DESCRIPTION
    Checks websites for newer versions using an (optional) regular expression defined in the manifest.
.PARAMETER App
    Manifest name to search.
    Wildcards are supported.
.PARAMETER Dir
    Where to search for manifest(s).
.PARAMETER Update
    Update given manifest
.PARAMETER ForceUpdate
    Update given manifest(s) even when there is no new version.
    Useful for hash updates.
.PARAMETER SkipUpdated
    Updated manifests will not be shown.
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
        if (!(Test-Path $_ -Type Container)) { throw "$_ is not a directory!" }
        $true
    })]
    [String] $Dir,
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipUpdated,
    [String] $Version = ''
)

'core', 'manifest', 'buckets', 'autoupdate', 'json', 'Versions', 'install' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

$Dir = Resolve-Path $Dir
$Search = $App
$Queue = @()
$GITHUB_REGEX = '/releases/tag/[vV]?([\d.]+)'

#region Functions
function next($AppName, $Err) {
    Write-Host "${AppName}: " -NoNewline
    Write-Host $Err -ForegroundColor DarkRed
    # Just throw something to invoke try-catch
    throw 'error'
}

function Invoke-Check {
    param([Parameter(Mandatory, ValueFromPipeline)] [System.Management.Automation.PSEventArgs] $Event)

    $state = $Event.SourceEventArgs.UserState

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

    $page = $Event.SourceEventArgs.Result
    $err = $Event.SourceEventArgs.Error

    if (Test-ScoopDebugEnabled) { Set-Content "$PWD\checkver-page.html" $page -Encoding Ascii }
    if ($json.checkver.script) { $page = $json.checkver.script -join "`r`n" | Invoke-Expression }
    if (Test-ScoopDebugEnabled) { Set-Content "$PWD\checkver-page-script.html" $page -Encoding Ascii }

    if ($err) { next  $appName "$($err.Message)`r`nURL $url is not valid" }
    if (!$regex -and $replace) { next $appName "'replace' requires 're' or 'regex'" }

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
        if (!$ver) { next $appName "couldn't find '$xpath' in $url" }
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
            next $appName "couldn't match '$regexp' in $url"
        }
    }

    if (!$ver) { next $appName "couldn't find new version in $url" }

    # Skip actual only if versions are same and there is no -f
    if (($ver -eq $expectedVersion) -and !$ForceUpdate -and $SkipUpdated) { return }

    Write-Host "${appName}: " -NoNewline

    # version hasn't changed (step over if forced update)
    if ($ver -eq $expectedVersion -and !$ForceUpdate) {
        Write-Host $ver -ForegroundColor DarkGreen
        return
    }

    Write-Host $ver -ForegroundColor DarkRed -NoNewline
    Write-Host " (scoop version is $expectedVersion)" -NoNewline
    $updateAvailable = (Compare-Version -ReferenceVersion $expectedVersion -DifferenceVersion $ver) -ne 0

    if ($json.autoupdate -and $updateAvailable) {
        Write-Host ' autoupdate available' -ForegroundColor Cyan
    } else {
        Write-Host ''
    }

    # Forcing an update implies updating
    if ($ForceUpdate) { $Update = $true }

    if ($Update -and $json.autoupdate) {
        if ($ForceUpdate) { Write-Host 'Forcing autoupdate!' -ForegroundColor DarkMagenta }
        try {
            if ($Version -ne '') { $ver = $Version }

            autoupdate $appName $Dir $json $ver $matchesHashtable
        } catch {
            Write-UserMessage -Message $_.Exception.Message -Err
        }
    }
}
#endregion Functions

# Clear any existing events
Get-Event | ForEach-Object { Remove-Event $_.SourceIdentifier }

#region Main
Get-ChildItem $Dir "$App.json" | ForEach-Object {
    $m = parse_json (Join-Path $Dir\ $_.Name)
    if ($m.checkver) { $Queue += , @($_.Name, $m) }
}

foreach ($q in $Queue) {
    $name, $json = $q

    $substitutions = get_version_substitutions $json.version

    $wc = New-Object Net.Webclient
    $ua = $json.checkver.useragent
    $ua = if ($ua) { substitute $ua $substitutions } else { Get-UserAgent }
    $wc.Headers.Add('User-Agent', $ua)

    Register-ObjectEvent $wc DownloadStringCompleted -ErrorAction Stop | Out-Null

    $url = $json.homepage
    $regex = ''
    $jsonpath = ''
    $xpath = ''
    $replace = ''
    $reverse = $json.checkver.reverse -and $json.checkver.reverse -eq 'true'

    if ($json.checkver.url) { $url = $json.checkver.url }

    if ($json.checkver -eq 'github') {
        if (!$json.homepage.StartsWith('https://github.com/')) {
            Write-UserMessage -Message "$name checkver expects the homepage to be a github repository" -Err
        }
        $url = $json.homepage + '/releases/latest'
        $regex = $GITHUB_REGEX
    }
    if ($json.checkver.github) {
        $url = $json.checkver.github + '/releases/latest'
        $regex = $GITHUB_REGEX
    }

    if ($json.checkver.re) {
        Write-UserMessage -Message "${name}: 're' is deprecated. Use 'regex' instead" -Err
        $regex = $json.checkver.re
    }
    if ($json.checkver.jp) {
        Write-UserMessage -Message "${name}: 'jp' is deprecated. Use 'jsonpah' instead" -Err
        $jsonpath = $json.checkver.jp
    }

    if ($json.checkver.regex) { $regex = $json.checkver.regex }
    if ($json.checkver.jsonpath) { $jsonpath = $json.checkver.jsonpath }
    if ($json.checkver.xpath) { $xpath = $json.checkver.xpath }
    if ($json.checkver.replace -and $json.checkver.replace.GetType() -eq [System.String]) { $replace = $json.checkver.replace }
    if (!$jsonpath -and !$regex -and !$xpath) { $regex = $json.checkver }

    $url = substitute $url $substitutions

    $state = New-Object PSObject @{
        'app'      = (strip_ext $name)
        'url'      = $url
        'regex'    = $regex
        'json'     = $json
        'jsonpath' = $jsonpath
        'xpath'    = $xpath
        'reverse'  = $reverse
        'replace'  = $replace
    }

    $wc.Headers.Add('Referer', (strip_filename $url))
    $wc.DownloadStringAsync($url, $state)
}

# wait for all to complete
$inProgress = 0
while ($inProgress -lt $Queue.Length) {
    $ev = Wait-Event
    Remove-Event $ev.SourceIdentifier
    ++$inProgress

    try {
        Invoke-Check $ev
    } catch {
        continue
    }
}
#endregion Main
