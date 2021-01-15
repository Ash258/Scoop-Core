'core', 'Helpers', 'manifest' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

$VT_API_KEY = get_config 'virustotal_api_key'
$VT_ERR = @{
    'Unsafe'    = 2
    'Exception' = 4
    'NoInfo'    = 8
}

function Get-VirusTotalResult {
    <#
    .SYNOPSIS
        Parse VirusTotal statistics and notify user.
    .PARAMETER Hash
        Specifies the hash of file to search for.
    .PARAMETER App
        Specifies the name of application.
    .OUTPUTS Int
        Exit code
    #>
    [CmdletBinding()]
    [OutputType([Int])]
    param(
        [Parameter(Mandatory)]
        [String] $Hash,
        [Parameter(Mandatory)]
        [String] $App
    )

    $Hash = $Hash.ToLower()
    $apiUrl = "https://www.virustotal.com/api/v3/search?query=$hash"
    $detectionUrl = "https://www.virustotal.com/#/file/$hash/detection"

    $wc = New-Object System.Net.Webclient
    $wc.Headers.Add('User-Agent', (Get-UserAgent))
    $wc.Headers.Add('x-apikey', $VT_API_KEY)

    try {
        $result = $wc.DownloadString($apiUrl)
        $stats = json_path $result '$.data..attributes.last_analysis_stats'
    } catch {
        throw '(404) File not found' # Always throw 404 to trigger submit
    }
    $malicious = json_path $stats '$.malicious'
    $suspicious = json_path $stats '$.suspicious'
    $undetected = json_path $stats '$.undetected'
    $unsafe = [int]$malicious + [int]$suspicious

    switch ($unsafe) {
        0 { $fg = if ($undetected -eq 0) { 'Yellow' } else { 'DarkGreen' } }
        1 { $fg = 'DarkYellow' }
        2 { $fg = 'Yellow' }
        default { $fg = 'Red' }
    }

    Write-UserMessage -Message "${App}: $unsafe/$undetected, see '$detectionUrl'" -Color $fg
    $ret = if ($unsafe -gt 0) { $VT_ERR.Unsafe } else { 0 }

    return $ret
}

function Search-VirusTotal {
    <#
    .SYNOPSIS
        Wrapper arround Get-VirusTotalResult for validation.
    .PARAMETER Hash
        Specifies the hash of file to search for.
    .PARAMETER App
        Specifies the name of application.
    .OUTPUTS Int
        Exit code
    #>
    [CmdletBinding()]
    [OutputType([Int])]
    param(
        [Parameter(Mandatory)]
        [String] $Hash,
        [Parameter(Mandatory)]
        [String] $App
        # TODO: Add -Download option to bypass unsupported hash - Download file, get hash, delete the file
    )
    $algorithm, $pureHash = $Hash -split ':'
    if (!$pureHash) {
        $pureHash = $algorithm
        $algorithm = 'sha256'
    }

    if ($algorithm -notin 'md5', 'sha1', 'sha256') {
        Write-UserMessage -Message "${App}: Unsopported hash algorithm $algorithm", 'Virustotal requires md5, sha1 or sha256' -Warning
        return $VT_ERR.NoInfo
    }

    return Get-VirusTotalResult $pureHash $App
}

function Submit-RedirectedUrl {
    <#
    .SYNOPSIS
        Follow redirection in case of 3xx status codes
        Short description
    .PARAMETER URL
        Specifies the URL of the internet resource to which the web request is sent.
    .OUTPUTS String
        Redirected URL.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param ([Parameter(Mandatory, ValueFromPipeline)] [String] $URL)

    process {
        $request = [System.Net.WebRequest]::Create($URL)
        $request.AllowAutoRedirect = $false
        $response = $request.GetResponse()

        if (([int]$response.StatusCode -ge 300) -and ([int]$response.StatusCode -lt 400)) {
            $redir = $response.GetResponseHeader('Location')
        } else {
            $redir = $URL
        }

        $response.Close()

        return $redir
    }
}

function Submit-ToVirusTotal {
    <#
    .SYNOPSIS
        Upload file to VirusTotal and
    .PARAMETER URL
        Specifies the URL of application assets.
    .PARAMETER App
        Specifies the name of the application. Used for reporting.
    .PARAMETER DoScan
        Specifies if the file should be uploaded to VirusTotal.
        Otherwise user will be prompted to Upload the file manually.
    .PARAMETER Retry
        Specifies to retry upload after delay in case of rate limit.
    #>
    param(
        [Parameter(Mandatory)]
        [String] $Url,
        [String] $App,
        [Switch] $DoScan,
        [Switch] $Retry
    )

    # Requests counter to slow down requests submitted to VirusTotal as script execution progresses
    $requests = 0

    try {
        # Follow redirections (for e.g. sourceforge URLs) because
        # VirusTotal analyzes only "direct" download links
        $Url = ($Url -split '#/')[0]
        $newRedir = $Url
        do {
            $origRedir = $newRedir
            $newRedir = Submit-RedirectedUrl $origRedir
        } while ($origRedir -ne $newRedir)

        $requests += 1
        $params = @{
            'Method'  = 'Post'
            'Headers' = @{
                'x-apikey' = $VT_API_KEY
            }
        }
        $result = Invoke-WebRequest -Uri 'https://www.virustotal.com/api/v3/urls' @params -Body @{ 'url' = $newRedir } -UseBasicParsing

        if ($result.StatusCode -eq 200) {
            try {
                $cont = ConvertFrom-Json $result.Content
                $params.Method = 'Get'
                $perm = Invoke-RestMethod -Uri "https://www.virustotal.com/api/v3/analyses/$($cont.data.id)" @params
                $lastLine = $perm.meta.url_info.id
                $lastLine = "    In meantime you can visit: 'https://www.virustotal.com/gui/url/$lastLine/detection'"
            } catch {
                $lastLine = $null
            }

            Write-UserMessage -Message @(
                "${App}: not found. Submitted $Url"
                '    Wait a few minutes for VirusTotal to process the file before trying again'
                $lastLine
            ) -Warning
            return
        }

        # EAFP: submission failed -> sleep, then retry
        $explained = $false
        if (!$Retry) {
            if (!$explained) {
                Write-UserMessage -Message 'Sleeping 60+ seconds between requests due to VirusTotal''s 4/min limit'
                $explained = $true
            }
            Start-Sleep -Seconds (60 + $requests)
            Submit-ToVirusTotal $newRedir $App -DoScan:$DoScan -Retry
        } else {
            Write-UserMessage -Message "${App}: VirusTotal submission of $Url failed.", "API returened $($result.StatusCode) after retrying" -Warning
        }
    } catch {
        Write-UserMessage -Message "${App}: VirusTotal submission failed: $($_.Exception.Message)" -Warning
        return
    }
}
