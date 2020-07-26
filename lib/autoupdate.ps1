'core', 'json', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function find_hash_in_rdf([String] $url, [String] $basename) {
    $data = $null
    try {
        # Download and parse RDF XML file
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('Referer', (strip_filename $url))
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $data = $wc.DownloadString($url)
    } catch [System.Net.WebException] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed

        return $null
    }
    if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-hash-rdf.html' | Out-UTF8Content -Content $data }
    $data = [xml] $data

    # Find file content
    $digest = $data.RDF.Content | Where-Object { [String]$_.about -eq $basename }

    return format_hash $digest.sha256
}

function find_hash_in_textfile([String] $url, [Hashtable] $substitutions, [String] $regex) {
    $hashfile = $null

    $templates = @{
        '$md5'      = '([a-fA-F0-9]{32})'
        '$sha1'     = '([a-fA-F0-9]{40})'
        '$sha256'   = '([a-fA-F0-9]{64})'
        '$sha512'   = '([a-fA-F0-9]{128})'
        '$checksum' = '([a-fA-F0-9]{32,128})'
        '$base64'   = '([a-zA-Z0-9+\/=]{24,88})'
    }

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('Referer', (strip_filename $url))
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $hashfile = $wc.DownloadString($url)
    } catch [System.Net.WebException] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed
        return
    }
    if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-hash-txt.html' | Out-UTF8Content -Content $hashfile }

    if ($regex.Length -eq 0) { $regex = '^([a-fA-F0-9]+)$' }

    $regex = substitute $regex $templates $false
    $regex = substitute $regex $substitutions $true

    debug $regex

    if ($hashfile -match $regex) { $hash = $Matches[1] -replace '\s' }

    # Convert base64 encoded hash values
    if ($hash -match '^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=|[A-Za-z0-9+\/]{4})$') {
        $base64 = $Matches[0]
        if (!($hash -match '^[a-fA-F0-9]+$') -and $hash.Length -notin @(32, 40, 64, 128)) {
            try {
                $hash = ([System.Convert]::FromBase64String($base64) | ForEach-Object { $_.ToString('x2') }) -join ''
            } catch {
                $hash = $hash
            }
        }
    }

    # Find hash with filename in $hashfile
    if ($hash.Length -eq 0) {
        $filenameRegex = "([a-fA-F0-9]{32,128})[\x20\t]+.*`$basename(?:[\x20\t]+\d+)?"
        $filenameRegex = substitute $filenameRegex $substitutions $true
        if ($hashfile -match $filenameRegex) {
            $hash = $Matches[1]
        }
        $metalinkRegex = '<hash[^>]+>([a-fA-F0-9]{64})'
        if ($hashfile -match $metalinkRegex) {
            $hash = $Matches[1]
        }
    }

    return format_hash $hash
}

function find_hash_in_json([String] $url, [Hashtable] $substitutions, [String] $jsonpath) {
    $json = $null

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('Referer', (strip_filename $url))
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $json = $wc.DownloadString($url)
    } catch [System.Net.WebException] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed
        return
    }
    if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-hash-json.html' | Out-UTF8Content -Content $json }

    $hash = json_path $json $jsonpath $substitutions
    if (!$hash) {
        $hash = json_path_legacy $json $jsonpath $substitutions
    }

    return format_hash $hash
}

function find_hash_in_xml([String] $url, [Hashtable] $substitutions, [String] $xpath) {
    $xml = $null

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('Referer', (strip_filename $url))
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $xml = $wc.DownloadString($url)
    } catch [System.Net.WebException] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed
        return
    }

    if (Test-ScoopDebugEnabled) { Join-Path $PWD 'checkver-hash-xml.html' | Out-UTF8Content -Content $xml }
    $xml = [xml] $xml

    # Replace placeholders
    if ($substitutions) { $xpath = substitute $xpath $substitutions }

    # Find all `significant namespace declarations` from the XML file
    $nsList = $xml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]')
    # Then add them into the NamespaceManager
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsList | ForEach-Object {
        $nsmgr.AddNamespace($_.LocalName, $_.Value)
    }

    # Getting hash from XML, using XPath
    $hash = $xml.SelectSingleNode($xpath, $nsmgr).'#text'

    return format_hash $hash
}

function find_hash_in_headers([String] $url) {
    $hash = $null

    try {
        $req = [System.Net.WebRequest]::Create($url)
        $req.Referer = (strip_filename $url)
        $req.AllowAutoRedirect = $false
        $req.UserAgent = (Get-UserAgent)
        $req.Timeout = 2000
        $req.Method = 'HEAD'
        $res = $req.GetResponse()
        if (([int]$response.StatusCode -ge 300) -and ([int]$response.StatusCode -lt 400)) {
            if ($res.Headers['Digest'] -match 'SHA-256=([^,]+)' -or $res.Headers['Digest'] -match 'SHA=([^,]+)' -or $res.Headers['Digest'] -match 'MD5=([^,]+)') {
                $hash = ([System.Convert]::FromBase64String($Matches[1]) | ForEach-Object { $_.ToString('x2') }) -join ''
                debug $hash
            }
        }
        $res.Close()
    } catch [System.Net.WebException] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed
        return
    }

    return format_hash $hash
}

function get_hash_for_app([String] $app, $config, [String] $version, [String] $url, [Hashtable] $substitutions) {
    $hash = $null

    $hashmode = $config.mode
    $basename = [System.Web.HttpUtility]::UrlDecode((url_remote_filename($url)))

    $substitutions = $substitutions.Clone()
    $substitutions.Add('$url', (strip_fragment $url))
    $substitutions.Add('$baseurl', (strip_filename (strip_fragment $url)).TrimEnd('/'))
    $substitutions.Add('$basename', $basename)
    $substitutions.Add('$urlNoExt', (strip_ext (strip_fragment $url)))
    $substitutions.Add('$basenameNoExt', (strip_ext $basename))

    debug $substitutions

    $hashfile_url = substitute $config.url $substitutions

    debug $hashfile_url

    if ($hashfile_url) {
        Write-Host 'Searching hash for ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $basename -ForegroundColor Green -NoNewline
        Write-Host ' in ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $hashfile_url -ForegroundColor Green
    }

    if ($hashmode.Length -eq 0 -and $config.url.Length -ne 0) {
        $hashmode = 'extract'
    }

    $jsonpath = ''
    if ($config.jp) {
        Write-UserMessage -Message '''jp'' property is deprecated. Use ''jsonpath'' instead.' -Err
        $jsonpath = $config.jp
        $hashmode = 'json'
    }
    if ($config.jsonpath) {
        $jsonpath = $config.jsonpath
        $hashmode = 'json'
    }
    $regex = ''
    if ($config.find) {
        Write-UserMessage -Message '''find'' property is deprecated. Use ''regex'' instead.' -Err
        $regex = $config.find
    }
    if ($config.regex) {
        $regex = $config.regex
    }

    $xpath = ''
    if ($config.xpath) {
        $xpath = $config.xpath
        $hashmode = 'xpath'
    }

    if (!$hashfile_url -and $url -match '^(?:.*fosshub.com\/).*(?:\/|\?dwl=)(?<filename>.*)$') {
        $hashmode = 'fosshub'
    }

    if (!$hashfile_url -and $url -match '(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*)') {
        $hashmode = 'sourceforge'
    }

    switch ($hashmode) {
        'extract' {
            $hash = find_hash_in_textfile $hashfile_url $substitutions $regex
        }
        'json' {
            $hash = find_hash_in_json $hashfile_url $substitutions $jsonpath
        }
        'xpath' {
            $hash = find_hash_in_xml $hashfile_url $substitutions $xpath
        }
        'rdf' {
            $hash = find_hash_in_rdf $hashfile_url $basename
        }
        'metalink' {
            $hash = find_hash_in_headers $url
            if (!$hash) {
                $hash = find_hash_in_textfile "$url.meta4" $substitutions
            }
        }
        'fosshub' {
            $hash = find_hash_in_textfile $url $substitutions ($Matches.filename + '.*?"sha256":"([a-fA-F0-9]{64})"')
        }
        'sourceforge' {
            # Change the URL because downloads.sourceforge.net doesn't have checksums
            $hashfile_url = (strip_filename (strip_fragment "https://sourceforge.net/projects/$($Matches['project'])/files/$($Matches['file'])")).TrimEnd('/')
            $hash = find_hash_in_textfile $hashfile_url $substitutions '"$basename":.*?"sha1":\s"([a-fA-F0-9]{40})"'
        }
    }

    if ($hash) {
        Write-Host 'Found: ' -ForegroundColor DarkYellow -NoNewline
        Write-Host $hash -ForegroundColor Green -NoNewline
        Write-Host ' using ' -ForegroundColor DarkYellow -NoNewline
        Write-Host  "$((Get-Culture).TextInfo.ToTitleCase($hashmode)) Mode" -ForegroundColor Green

        return $hash
    } elseif ($hashfile_url) {
        Write-UserMessage -Message "Could not find hash in $hashfile_url" -Color DarkYellow
    }

    Write-Host 'Downloading ' -ForegroundColor DarkYellow -NoNewline
    Write-Host $basename -ForegroundColor Green -NoNewline
    Write-Host ' to compute hashes!' -ForegroundColor DarkYellow

    try {
        dl_with_cache $app $version $url $null $null $true
    } catch [system.net.webexception] {
        Write-UserMessage -Message $_, "URL $url is not valid" -Color DarkRed
        return $null
    }
    $file = cache_path $app $version $url
    $hash = compute_hash $file 'sha256'
    Write-Host 'Computed hash: ' -ForegroundColor DarkYellow -NoNewline
    Write-Host $hash -ForegroundColor Green

    return $hash
}

function update_manifest_with_new_version($json, [String] $version, [String] $url, [String] $hash, $architecture = $null) {
    $json.version = $version

    if ($null -eq $architecture) {
        if ($json.url -is [System.Array]) {
            $json.url[0] = $url
            $json.hash[0] = $hash
        } else {
            $json.url = $url
            $json.hash = $hash
        }
    } else {
        # If there are multiple urls we replace the first one
        if ($json.architecture.$architecture.url -is [System.Array]) {
            $json.architecture.$architecture.url[0] = $url
            $json.architecture.$architecture.hash[0] = $hash
        } else {
            $json.architecture.$architecture.url = $url
            $json.architecture.$architecture.hash = $hash
        }
    }
}

function update_manifest_prop([String] $prop, $json, [Hashtable] $substitutions) {
    # first try the global property
    if ($json.$prop -and $json.autoupdate.$prop) {
        $json.$prop = substitute $json.autoupdate.$prop $substitutions
    }

    # check if there are architecture specific variants
    if ($json.architecture -and $json.autoupdate.architecture) {
        $json.architecture | Get-Member -MemberType NoteProperty | ForEach-Object {
            $architecture = $_.Name
            if ($json.architecture.$architecture.$prop -and $json.autoupdate.architecture.$architecture.$prop) {
                $json.architecture.$architecture.$prop = substitute (arch_specific $prop $json.autoupdate $architecture) $substitutions
            }
        }
    }
}

function get_version_substitutions([String] $version, [Hashtable] $customMatches) {
    $firstPart = $version -split '-' | Select-Object -First 1
    $lastPart = $version -split '-' | Select-Object -Last 1
    $versionVariables = @{
        '$version'           = $version
        '$underscoreVersion' = ($version -replace '\.', '_')
        '$dashVersion'       = ($version -replace '\.', '-')
        '$cleanVersion'      = ($version -replace '\.')
        '$majorVersion'      = ($firstPart -split '\.' | Select-Object -First 1)
        '$minorVersion'      = ($firstPart -split '\.' | Select-Object -Skip 1 -First 1)
        '$patchVersion'      = ($firstPart -split '\.' | Select-Object -Skip 2 -First 1)
        '$buildVersion'      = ($firstPart -split '\.' | Select-Object -Skip 3 -First 1)
        '$preReleaseVersion' = $lastPart
    }
    if ($version -match '(?<head>\d+\.\d+(?:\.\d+)?)(?<tail>.*)') {
        $versionVariables.Set_Item('$matchHead', $Matches['head'])
        $versionVariables.Set_Item('$matchTail', $Matches['tail'])
    }
    if ($customMatches) {
        $customMatches.GetEnumerator() | ForEach-Object {
            if ($_.Name -ne '0') {
                $versionVariables.Set_Item('$match' + (Get-Culture).TextInfo.ToTitleCase($_.Name), $_.Value)
            }
        }
    }

    return $versionVariables
}

function autoupdate([String] $app, $dir, $json, [String] $version, [Hashtable] $MatchesHashtable) {
    Write-UserMessage -Message "Autoupdating $app" -Color DarkCyan
    $has_changes = $false
    $has_errors = $false
    [bool] $valid = $true
    $substitutions = get_version_substitutions $version $MatchesHashtable

    if ($json.url) {
        # Create new url
        $url = substitute $json.autoupdate.url $substitutions
        $valid = $true

        if ($valid) {
            # Create hash
            $hash = get_hash_for_app $app $json.autoupdate.hash $version $url $substitutions
            if ($null -eq $hash) {
                $valid = $false
                Write-UserMessage -Message 'Could not find hash!' -Color DarkRed
            }
        }

        # Write changes to the json object
        if ($valid) {
            $has_changes = $true
            update_manifest_with_new_version $json $version $url $hash
        } else {
            $has_errors = $true
            throw "Could not update $app"
        }
    } else {
        $json.architecture | Get-Member -MemberType NoteProperty | ForEach-Object {
            $valid = $true
            $architecture = $_.Name

            # Create new url
            $url = substitute (arch_specific "url" $json.autoupdate $architecture) $substitutions
            $valid = $true

            if ($valid) {
                # Create hash
                $hash = get_hash_for_app $app (arch_specific "hash" $json.autoupdate $architecture) $version $url $substitutions
                if ($null -eq $hash) {
                    $valid = $false
                    Write-UserMessage -Message 'Could not find hash!' -Color DarkRed
                }
            }

            # Write changes to the json object
            if ($valid) {
                $has_changes = $true
                update_manifest_with_new_version $json $version $url $hash $architecture
            } else {
                $has_errors = $true
                throw "Could not update $app $architecture"
            }
        }
    }

    # Update properties
    update_manifest_prop 'extract_dir' $json $substitutions

    # Update license
    update_manifest_prop 'license' $json $substitutions

    if ($has_changes -and !$has_errors) {
        # Write file
        Write-UserMessage -Message "Writing updated $app manifest" -Color DarkGreen

        $path = Join-Path $dir "$app.json"

        $json | ConvertToPrettyJson | Out-UTF8File -Path $path

        # Notes
        if ($json.autoupdate.note) {
            Write-UserMessage -Message '', $json.autoupdate.note -Color DarkYellow
        }
    } else {
        Write-UserMessage -Message "No updates for $app" -Color DarkGray
    }
}
