function Write-UserMessage {
    <#
    .SYNOPSIS
        Print message to the user using Write-Host.
    .DESCRIPTION
        Based on passed severity the message will have different color and prefix.
    .PARAMETER Message
        Specifies the message to be displayed to user.
    .PARAMETER Severity
        Specifies the severity of the message.
        Could be Message, Info, Warning, Error, Success
    .PARAMETER Output
        Specifies the Write-Output cmdlet is used instead of Write-Host
    .PARAMETER Info
        Same as -Severity Info
    .PARAMETER Warning
        Same as -Severity warning
    .PARAMETER Err
        Same as -Severity Error
    .PARAMETER Success
        Same as -Severity Success
    .PARAMETER SkipSeverity
        Specifies the output will not contains severity prefix.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [String[]] $Message,
        [ValidateSet('Message', 'Info', 'Warning', 'Error', 'Success')]
        [String] $Severity = 'Message',
        [Switch] $Output,
        [Switch] $Info,
        [Switch] $Warning,
        [Switch] $Err,
        [Switch] $Success,
        [Switch] $SkipSeverity,
        [Alias('ForegroundColor')]
        [System.ConsoleColor] $Color = $(if ($Host.UI.RawUI.ForegroundColor -and !$IsLinux) { $Host.UI.RawUI.ForegroundColor } else { 'White' })
    )

    begin {
        if ($Info) { $Severity = 'Info' }
        if ($Warning) { $Severity = 'Warning' }
        if ($Err) { $Severity = 'Error' }
        if ($Success) { $Severity = 'Success' }

        switch ($Severity) {
            'Info' { $sev = 'INFO  '; $foreColor = 'DarkGray' }
            'Warning' { $sev = 'WARN  '; $foreColor = 'DarkYellow' }
            'Error' { $sev = 'ERROR '; $foreColor = 'DarkRed' }
            'Success' { $sev = ''; $foreColor = 'DarkGreen' }
            default {
                $sev = ''
                $foreColor = 'White'
                # If color is white (default) and there is no output => Write-Host
                # If color other than White is passed => Write-Host
                if ((($Color -eq 'White') -and !$Output) -or ($Color -ne 'White')) {
                    $foreColor = $Color
                } else {
                    $Output = $true
                }
            }
        }
        $display = @()
    }

    process {
        $m = if ($SkipSeverity) { $Message } else { $Message -replace '^', "$sev" }
        $display += $m
    }

    end {
        $display = $display -join "`r`n"
        if ($Output) {
            Write-Output $display
        } else {
            Write-Host $display -ForegroundColor $foreColor
        }
    }
}

function Confirm-DirectoryExistence {
    <#
    .SYNOPSIS
        Make sure that directory exists. ensure replacement
    .PARAMETER Directory
        Specifies directory to be tested and created.
    .OUTPUTS
        System.Management.Automation.PathInfo
            Resolved path
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PathInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Dir', 'Path', 'LiteralPath', 'InputObject')]
        [String] $Directory
    )

    process {
        if (!(Test-Path -LiteralPath $Directory -PathType 'Container')) { New-Item $Directory -ItemType 'Directory' | Out-Null }

        return Resolve-Path $Directory
    }
}

function Stop-ScoopExecution {
    <#
    .SYNOPSIS
        Print error message and exit scoop execution with given Exit code.
    .DESCRIPTION
        This function should be used only as the last thing, where there is not possible to recover from error state or
        if you can freely exit entire execution without causing problems to user.
        If it is called there is no failsafe / error state handling.
        For Example. When there is installation of multiple applications happening, and first fail. This function
        is called, and rest of applications are not installed, which is not user friendly.
    .PARAMETER Message
        Specifies the tessage, which will be printed to user.
    .PARAMETER ExitCode
        Specifies the exit code.
    #>
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String[]] $Message,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [Int] $ExitCode = 3,
        [String[]] $Usage,
        [Switch] $SkipSeverity
    )

    begin { if ($Usage) { $ExitCode = 1 } }

    process {
        Write-UserMessage -Message $Message -Err:(!$SkipSeverity)
        if ($Usage) {
            Write-UserMessage -Message $Usage -Output
        }
    }

    end { exit $ExitCode }
}

function Out-UTF8File {
    <#
    .SYNOPSIS
        Write UTF8 (no-bom) file.
    .DESCRIPTION
        Use Set-Content -encoding utf8 on pwsh and WriteAllLines on powershell.
    .PARAMETER Path
        Specifies filename to be written.
    .PARAMETER Content
        Specifies content of to be written to file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'LiteralPath')]
        [System.IO.FileInfo] $File,
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [Alias('Value')]
        $Content
    )
    process {
        if ($null -eq $Content) { return }
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Set-Content -LiteralPath $File -Value $Content -Encoding 'utf8'
        } else {
            [System.IO.File]::WriteAllLines($File, ($Content -join "`r`n"))
        }
    }
}

function Out-UTF8Content {
    <#
    .SYNOPSIS
        Write UTF8 (no-bom) file.
    .DESCRIPTION
        Use Set-Content -encoding utf8 on pwsh and WriteAllLines on powershell.
        Takes File as pipeline instead of content.
    .PARAMETER Path
        Specifies filename to be written.
    .PARAMETER Content
        Specifies content to be written to file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'LiteralPath')]
        [System.IO.FileInfo] $File,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [Alias('Value')]
        $Content
    )

    process { Out-UTF8File -File $File -Content $Content }
}

function Get-MagicByte {
    <#
    .SYNOPSIS
        Get file's first 8 bytes.
    .PARAMETER File
        Specifies the file.
    .PARAMETER Pretty
        Specifies to return 'x2' representation of each byte.
    .PARAMETER Glue
        Specifies the characters used to join the bytes representation.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $File,
        [Switch] $Pretty,
        [String] $Glue = ' '
    )

    process {
        if (!(Test-Path $File -PathType 'Leaf')) { return '' }

        if ((Get-Command Get-Content).Parameters.ContainsKey('AsByteStream')) {
            # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
            $key = 'AsByteStream'
            $value = $true
        } else {
            $key = 'Encoding'
            $value = 'Byte'
        }
        $par = @{
            'LiteralPath' = $File
            'TotalCount'  = 8
            "$key"        = $value
        }

        $cont = Get-Content @par
        if ($Pretty) { $cont = $cont | ForEach-Object { $_.ToString('x2') } }
        $cont = $cont -join $Glue

        return $cont.ToUpper()
    }
}

function _resetAlias($name, $value) {
    $existing = Get-Alias $name -ErrorAction 'Ignore'

    if ($existing -and ($existing | Where-Object -Property 'Options' -Match 'readonly')) {
        if ($existing.Definition -ne $value) {
            Write-UserMessage "Alias $name is read-only; cannot reset it." -Warning
        }

        # Already set
        return
    }

    if ($value -is [ScriptBlock]) {
        if (!(Test-Path "Function:script:$name")) {
            New-Item -Path Function: -Name "script:$name" -Value $value | Out-Null
        }

        return
    }

    Set-Alias $name $value -Scope 'Script' -Option 'AllScope'
}

function Reset-Alias {
    # For aliases where there's a local function, re-alias so the function takes precedence
    $aliases = Get-Alias | Where-Object -Property 'Options' -NotMatch 'readonly|allscope' | Select-Object -ExpandProperty 'Name'
    Get-ChildItem Function: | ForEach-Object {
        $fn = $_.Name
        if ($fn -in $aliases) {
            Set-Alias $fn Local:$fn -Scope 'Script'
        }
    }

    # User aliases
    $defautlAliases = @{
        'cp'     = 'Copy-Item'
        'echo'   = 'Write-Output'
        'gc'     = 'Get-Content'
        'gci'    = 'Get-ChildItem'
        'gcm'    = 'Get-Command'
        'gm'     = 'Get-Member'
        'iex'    = 'Invoke-Expression'
        'ls'     = 'Get-ChildItem'
        'mkdir'  = { New-Item -Type 'Directory' @args }
        'mv'     = 'Move-Item'
        'rm'     = 'Remove-Item'
        'sc'     = 'Set-Content'
        'select' = 'Select-Object'
        'sls'    = 'Select-String'
    }

    # Set default aliases
    $defautlAliases.Keys | ForEach-Object { _resetAlias $_ $defautlAliases[$_] }
}

function New-IssuePrompt {
    <#
    .SYNOPSIS
        Prompt user to report a manifest problem to it's maintaners.
        Post direct link in case of supported source control provides.
    .PARAMETER Application
        Specifies the application name.
    .PARAMETER Bucket
        Specifies the bucket to which application belong
    .PARAMETER Title
        Specifies the title of newly created issue.
    .PARAMETER Body
        Specifies more details to be posted as issue body.
    #>
    param([String] $Application, [String] $Bucket, [String] $Title, [String[]] $Body)

    $Bucket = $Bucket.Trim()
    $app, $manifest, $Bucket, $url = Find-Manifest $Application $Bucket
    $url = known_bucket_repo $Bucket
    $bucketPath = Join-Path $SCOOP_BUCKETS_DIRECTORY $Bucket

    if ((Test-Path $bucketPath) -and (Join-Path $bucketPath '.git' | Test-Path -PathType 'Container')) {
        $remote = Invoke-GitCmd -Repository $bucketPath -Command 'config' -Argument '--get', 'remote.origin.url'
        # Support ssh and http syntax
        # git@PROVIDER:USER/REPO.git
        # https://PROVIDER/USER/REPO.git
        # https://regex101.com/r/OMEqfV
        if ($remote -match '(?:@|:\/\/)(?<provider>.+?)[:\/](?<user>.*)\/(?<repo>.+?)(?:\.git)?$') {
            $url = "https://$($Matches.Provider)/$($Matches.User)/$($Matches.Repo)"
        }
    }

    if (!$url) {
        Write-UserMessage -Message 'Please contact the manifest maintainer!' -Color 'DarkRed'
        return
    }

    $Title = [System.Web.HttpUtility]::UrlEncode("$Application@$($Manifest.version): $Title")
    $Body = [System.Web.HttpUtility]::UrlEncode($Body)
    $msg = "`nPlease try again"

    switch -Wildcard ($url) {
        '*github.*' {
            $url = $url -replace '\.git$'
            $url = "$url/issues/new?title=$Title"
            if ($body) { $url += "&body=$Body" }
            $msg = "$msg or create a new issue by using the following link and paste your console output:"
        }
        default {
            Write-UserMessage -Message 'Not supported platform' -Info
        }
    }

    Write-UserMessage -Message "$msg`n$url" -Color 'DarkRed'
}

function Get-NotePropertyEnumerator {
    <#
    .SYNOPSIS
        Line saver for evergreen ($object.PSObject.Properties | ? 'membertype' -eq 'noteproperty').GetEnumerator()
    .PARAMETER Object
        Specifes the object to be enumerated.
    #>
    [CmdletBinding()]
    param([PScustomObject] $Object)

    process {
        return @($Object.PSObject.Properties | Where-Object -Property 'MemberType' -EQ -Value 'NoteProperty').GetEnumerator()
    }
}

#region Exceptions
class ScoopException: System.Exception {
    $Message

    ScoopException([String] $Message) {
        $this.Message = $Message
    }
}
#endregion Exceptions
