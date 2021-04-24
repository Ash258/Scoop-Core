'Helpers', 'commands' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

# Such format is need to prevent automatic conversion of JSON date https://github.com/Ash258/Scoop-Core/issues/26
$UPDATE_DATE_FORMAT = '258|yyyy-MM-dd HH:mm:ss'

function Get-AbsolutePath {
    <#
    .SYNOPSIS
        Gets absolute path.
    .PARAMETER Path
        Specifies the path to evaluate.
    .OUTPUTS
        System.String
            Absolute path, may or maynot existed.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param([Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] [String] $Path)

    process { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
}

function Optimize-SecurityProtocol {
    # .NET Framework 4.7+ has a default security protocol called 'SystemDefault',
    # which allows the operating system to choose the best protocol to use.
    # If SecurityProtocolType contains 'SystemDefault' (means .NET4.7+ detected)
    # and the value of SecurityProtocol is 'SystemDefault', just do nothing on SecurityProtocol,
    # 'SystemDefault' will use TLS 1.2 if the webrequest requires.
    $isNewerNetFramework = ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'SystemDefault')
    $isSystemDefault = ([System.Net.ServicePointManager]::SecurityProtocol.Equals([System.Net.SecurityProtocolType]::SystemDefault))

    # If not, change it to support TLS 1.2
    if (!($isNewerNetFramework -and $isSystemDefault)) {
        # Set to TLS 1.2 (3072), then TLS 1.1 (768), and TLS 1.0 (192). Ssl3 has been superseded,
        # https://docs.microsoft.com/en-us/dotnet/api/system.net.securityprotocoltype?view=netframework-4.5
        [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192
    }
}

function Get-UserAgent {
    return "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64'){'WOW64; '})$PSEdition)"
}

function Show-DeprecatedWarning {
    <#
    .SYNOPSIS
        Print deprecated warning for functions, which will be deleted in near future.
    .PARAMETER Invocation
        $MyInvocation
    .PARAMETER New
        Specifies new command name.
    #>
    param($Invocation, [String] $New)

    Write-UserMessage -Message ('"{0}" will be deprecated. Please change your code/manifest to use "{1}"' -f $Invocation.MyCommand.Name, $New) -Warning
    Write-UserMessage -Message "      -> $($Invocation.PSCommandPath):$($Invocation.ScriptLineNumber):$($Invocation.OffsetInLine)" -Color 'DarkGray'
}

function Test-IsUnix {
    <#
    .SYNOPSIS
        Custom check to identify non-windows hosts.
    .DESCRIPTION
        $isWindows is not defind in PW5, thus null and boolean checks are needed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    process { return !(($null -eq $isWindows) -or ($isWindows -eq $true)) }
}

function Invoke-SystemComSpecCommand {
    <#
    .SYNOPSIS
        Wrapper around $env:ComSpec/$env:SHELL calls.
    .PARAMETER Windows
        Specifies the command to be executed on Windows using $env:ComSpec.
    .PARAMETER Unix
        Specifies the command to be executed on *Nix like systems using $env:SHELL.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $Windows,
        [Parameter(Mandatory)]
        [String] $Unix
    )

    process {
        if (Test-IsUnix) {
            $shell = $env:SHELL
            $parameters = @('-c', $Unix)
        } else {
            $shell = $env:ComSpec
            $parameters = @('/d', '/c', $Windows)
        }

        $debugShell = "& ""$shell"" $($parameters -join ' ')"
        debug $debugShell

        & "$shell" @parameters
    }
}

function load_cfg($file) {
    if (!(Test-Path $file)) { return $null }

    try {
        return (Get-Content $file -Raw | ConvertFrom-Json -ErrorAction 'Stop')
    } catch {
        Write-UserMessage -Message "loading ${file}: $($_.Exception.Message)" -Err
    }
}

function get_config($name, $default) {
    if (($null -eq $SCOOP_CONFIGURATION.$name) -and ($null -ne $default)) { return $default }

    return $SCOOP_CONFIGURATION.$name
}

function set_config($name, $value) {
    if ($null -eq $SCOOP_CONFIGURATION -or $SCOOP_CONFIGURATION.Count -eq 0) {
        Split-Path -Path $SCOOP_CONFIGURATION_FILE | ensure | Out-Null
        $SCOOP_CONFIGURATION = New-Object PSObject
        $SCOOP_CONFIGURATION | Add-Member -MemberType 'NoteProperty' -Name $name -Value $value
    } else {
        if ($value -eq [bool]::TrueString -or $value -eq [bool]::FalseString) {
            $value = [System.Convert]::ToBoolean($value)
        }
        if ($null -eq $SCOOP_CONFIGURATION.$name) {
            $SCOOP_CONFIGURATION | Add-Member -MemberType 'NoteProperty' -Name $name -Value $value
        } else {
            $SCOOP_CONFIGURATION.$name = $value
        }
    }

    if ($null -eq $value) { $SCOOP_CONFIGURATION.PSObject.Properties.Remove($name) }

    ConvertTo-Json $SCOOP_CONFIGURATION -Depth 10 | Out-UTF8File -Path $SCOOP_CONFIGURATION_FILE

    return $SCOOP_CONFIGURATION
}

function setup_proxy() {
    # '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
    $proxy = get_config 'proxy' 'none'

    if ($proxy -eq 'none') { return }

    try {
        $credentials, $address = $proxy -split '(?<!\\)@'
        if (!$address) {
            $address, $credentials = $credentials, $null # No credentials supplied
        }

        if ($address -eq 'none') {
            [System.Net.WebRequest]::DefaultWebProxy = $null
        } elseif ($address -ne 'default') {
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy "http://$address"
        }

        if ($credentials -eq 'currentuser') {
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        } elseif ($credentials) {
            $username, $password = $credentials -split '(?<!\\):' | ForEach-Object { $_ -replace '\\([@:])', '$1' }
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = New-Object System.Net.NetworkCredential($username, $password)
        }
    } catch {
        Write-UserMessage -Message "Failed to use proxy '$proxy': $($_.Exception.Message)" -Warning
    }
}

# helper functions
function coalesce($a, $b) { if ($a) { return $a } $b }

function format($str, $hash) {
    $hash.Keys | ForEach-Object { Set-Variable $_ $hash[$_] }
    $ExecutionContext.InvokeCommand.ExpandString($str)
}
function is_admin {
    $admin = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    return ([System.Security.Principal.WindowsPrincipal]($id)).IsInRole($admin)
}

# messages
function abort($msg, [int] $exit_code = 3) { Write-UserMessage -Message $msg -Err; exit $exit_code }
function error($msg) { Write-Host "ERROR $msg" -ForegroundColor 'DarkRed' }
function warn($msg) { Write-Host "WARN  $msg" -ForegroundColor 'DarkYellow' }
function info($msg) { Write-Host "INFO  $msg" -ForegroundColor 'DarkGray' }
function message($msg) { Write-Host "$msg" }

function Test-ScoopDebugEnabled {
    <#
    .SYNOPSIS
        Load debug information from $env:SCOOP_DEBUG or from config file.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $configDebug = (get_config 'debug' $false) -eq [bool]::TrueString
    $envDebug = $env:SCOOP_DEBUG
    $envDebug = ([bool] $envDebug) -or (($envDebug -eq [bool]::TrueString) -or ($envDebug -eq 1))

    return $configDebug -or $envDebug
}

function debug($obj) {
    <#
    .SYNOPSIS
        Output objects in specific format to help identifying problems.
    .PARAMETER obj
        Specifies object/variable to be shown.
    #>
    if (!(Test-ScoopDebugEnabled)) { return }

    $prefix = "DEBUG[$(Get-Date -UFormat %s)]"
    $param = $MyInvocation.Line.Replace($MyInvocation.InvocationName, '').Trim()
    $msg = $obj | Out-String -Stream

    if ($null -eq $obj -or $null -eq $msg) {
        Write-Host "$prefix $param = " -ForegroundColor 'DarkCyan' -NoNewline
        Write-Host '$null' -ForegroundColor 'DarkYellow' -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -ForegroundColor 'DarkGray'
        return
    }

    if ($msg.GetType() -eq [System.Object[]]) {
        Write-Host "$prefix $param ($($obj.GetType()))" -ForegroundColor 'DarkCyan' -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -ForegroundColor 'DarkGray'
        $msg | Where-Object { ![String]::IsNullOrWhiteSpace($_) } |
            Select-Object -Skip 2 | # Skip headers
                ForEach-Object {
                    Write-Host "$prefix $param.$($_)" -ForegroundColor 'DarkCyan'
                }
    } else {
        Write-Host "$prefix $param = $($msg.Trim())" -ForegroundColor 'DarkCyan' -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -ForegroundColor 'DarkGray'
    }
}
function success($msg) { Write-Host $msg -ForegroundColor 'DarkGreen' }

function filesize($length) {
    $gb = [System.Math]::Pow(2, 30)
    $mb = [System.Math]::Pow(2, 20)
    $kb = [System.Math]::Pow(2, 10)

    $size = "$($length) B"
    if ($length -gt $gb) {
        $size = '{0:n1} GB' -f ($length / $gb)
    } elseif ($length -gt $mb) {
        $size = '{0:n1} MB' -f ($length / $mb)
    } elseif ($length -gt $kb) {
        $size = '{0:n1} KB' -f ($length / $kb)
    }

    return $size
}

# dirs
function basedir($global) { if ($global) { return $SCOOP_GLOBAL_ROOT_DIRECTORY } $SCOOP_ROOT_DIRECTORY }
function appsdir($global) { return basedir $global | Join-Path -ChildPath 'apps' }
function shimdir($global) { return basedir $global | Join-Path -ChildPath 'shims' }
function appdir($app, $global) { return appsdir $global | Join-Path -ChildPath $app }
function versiondir($app, $version, $global) { return appdir $app $global | Join-Path -ChildPath $version }
function persistdir($app, $global) { return basedir $global | Join-Path -ChildPath "persist\$app" }
function usermanifestsdir { return Join-Path (basedir) 'workspace' }
function usermanifest($app) { return Join-Path (usermanifestsdir) "$app.json" }
function cache_path($app, $version, $url) {
    return Join-Path $SCOOP_CACHE_DIRECTORY "$app#$version#$($url -replace '[^\w\.\-]+', '_')"
}

# apps
function sanitary_path($path) { return [System.Text.RegularExpressions.Regex]::Replace($path, '[/\\?:*<>|]', '') }
function installed($app, $global = $null) {
    if ($null -eq $global) { return (installed $app $true) -or (installed $app $false) }
    # Dependencies of the format "bucket/dependency" install in a directory of form
    # "dependency". So we need to extract the bucket from the name and only give the app
    # name to is_directory
    $app = $app.split('/')[-1]

    return is_directory (appdir $app $global)
}
function installed_apps($global) {
    $dir = appsdir $global
    if (Test-Path $dir) { Get-ChildItem $dir -Exclude 'scoop' -Directory | Select-Object -ExpandProperty 'Name' }
}

function Get-AppFilePath {
    <#
    .SYNOPSIS
        Get full path to the specific executable under specific application installed via scoop.
    .PARAMETER App
        Specifies the scoop's application name.
    .PARAMETER File
        Specifies the executable name.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [String] $App,
        [Parameter(Mandatory)]
        [String] $File
    )

    # TODO: Support NO_JUNCTION
    # Normal path to file
    $path = versiondir $App 'current' $false | Join-Path -ChildPath $File
    if (Test-Path $path) { return $path }

    # Global path to file
    $path = versiondir $App 'current' $true | Join-Path -ChildPath $File
    if (Test-Path $path) { return $path }

    # Not found
    return $null
}

function Test-CommandAvailable {
    <#
    .SYNOPSIS
        Test if command is available in PATH.
    .PARAMETER Name
        Specifies the command name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ([Parameter(Mandatory, ValueFromPipeline)] [Alias('Command')] [String] $Name)

    process { return [bool] (Get-Command $Name -ErrorAction 'Ignore') }
}

function Get-HelperPath {
    <#
    .SYNOPSIS
        Get full path to the often used application's executables.
    .PARAMETER Helper
        Specifies the name of helper application.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateSet('7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2', 'Zstd', 'Innoextract')]
        [String] $Helper
    )

    process {
        $helperPath = $null
        switch ($Helper) {
            'Aria2' { $helperPath = Get-AppFilePath 'aria2' 'aria2c.exe' }
            'Innounp' { $helperPath = Get-AppFilePath 'innounp' 'innounp.exe' }
            'Lessmsi' { $helperPath = Get-AppFilePath 'lessmsi' 'lessmsi.exe' }
            'Zstd' { $HelperPath = Get-AppFilePath 'zstd' 'zstd.exe' }
            'Innoextract' { $HelperPath = Get-AppFilePath 'innoextract' 'innoextract.exe' }
            '7zip' {
                $helperPath = Get-AppFilePath '7zip' '7z.exe'
                if ([String]::IsNullOrEmpty($helperPath)) {
                    $helperPath = Get-AppFilePath '7zip-zstd' '7z.exe'
                }
            }
            'Dark' {
                $helperPath = Get-AppFilePath 'dark' 'dark.exe'
                if ([String]::IsNullOrEmpty($helperPath)) {
                    $helperPath = Get-AppFilePath 'wixtoolset' 'dark.exe'
                }
            }
        }

        return $helperPath
    }
}

function Test-HelperInstalled {
    <#
    .SYNOPSIS
        Test if specified widely used application is installed.
    .PARAMETER Helper
        Specifies the name of application.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateSet('7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2', 'Zstd', 'Innoextract')]
        [String] $Helper
    )

    process { return ![String]::IsNullOrWhiteSpace((Get-HelperPath -Helper $Helper)) }
}

function Test-Aria2Enabled {
    <#
    .SYNOPSIS
        Test if aria2 application is installed and enabled.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    process { return (Test-HelperInstalled -Helper 'Aria2') -and (get_config 'aria2-enabled' $true) }
}

function app_status($app, $global) {
    $status = @{ }
    $status.installed = (installed $app $global)
    $status.version = Select-CurrentVersion -AppName $app -Global:$global
    $status.latest_version = $status.version

    $install_info = install_info $app $status.version $global

    $status.failed = (!$install_info -or !$status.version)
    $status.hold = ($install_info.hold -eq $true)

    $manifest = manifest $app $install_info.bucket $install_info.url
    $status.bucket = $install_info.bucket
    $status.removed = (!$manifest)
    if ($manifest.version) {
        $status.latest_version = $manifest.version
    }

    $status.outdated = $false
    if ($status.version -and $status.latest_version) {
        $status.outdated = (Compare-Version -ReferenceVersion $status.version -DifferenceVersion $status.latest_version) -ne 0
    }

    $status.missing_deps = @()
    # TODO: Eliminate
    . (Join-Path $PSScriptRoot 'depends.ps1')
    $deps = @(runtime_deps $manifest) | Where-Object {
        $app, $bucket, $null = parse_app $_
        return !(installed $app)
    }

    if ($deps) { $status.missing_deps += , $deps }

    return $status
}

# TODO: YML
function appname_from_url($url) { return (Split-Path $url -Leaf) -replace '\.json$' }

# paths
function fname($path) { return Split-Path $path -Leaf }
function strip_ext($fname) { return $fname -replace '\.[^\.]*$' }
function strip_filename($path) { return $path -replace [System.Text.RegularExpressions.Regex]::Escape((fname $path)) }
function strip_fragment($url) { return $url -replace (New-Object System.Uri $url).Fragment }

function url_filename($url) { return (Split-Path $url -Leaf).Split('?') | Select-Object -First 1 }
# Unlike url_filename which can be tricked by appending a
# URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
# this function extracts the original filename from the URL.
function url_remote_filename($url) {
    $uri = (New-Object System.Uri $url)
    $basename = Split-Path $uri.PathAndQuery -Leaf
    If ($basename -match '.*[?=]+([\w._-]+)') {
        $basename = $matches[1]
    }
    If (($basename -notlike '*.*') -or ($basename -match '^[v.\d]+$')) {
        $basename = Split-Path $uri.AbsolutePath -Leaf
    }
    If (($basename -notlike '*.*') -and ($uri.Fragment -ne '')) {
        $basename = $uri.Fragment.Trim('/', '#')
    }

    return $basename
}

function ensure {
    <#
    .SYNOPSIS
        Make sure that directory exists.
    .PARAMETER Directory
        Specifies directory to be tested and created.
    .OUTPUTS
        System.Management.Automation.PathInfo
            Resolved path
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PathInfo])]
    param([Parameter(Mandatory, ValueFromPipeline)] [Alias('Dir', 'Path', 'LiteralPath')] $Directory)

    process {
        if (!(Test-Path $Directory)) { New-Item $Directory -ItemType 'Directory' | Out-Null }

        return Resolve-Path $Directory
    }
}

function relpath {
    <#
    .SYNOPSIS
        Returns relative path to caller.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param([String] $Path)

    process { return Join-Path $MyInvocation.PSScriptRoot $Path }
}

function friendly_path($path) {
    $h = (Get-PSProvider 'FileSystem').Home
    if (!$h.EndsWith('\')) { $h += '\' }
    if ($h -eq '\') { return $path }

    return "$path" -replace ([System.Text.RegularExpressions.Regex]::Escape($h)), '~\'
}
function is_local($path) { return ($path -notmatch '^https?://') -and (Test-Path $path) }

# operations

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
        Run command using System.Diagnostics.Process with support for logs.
    .PARAMETER FilePath
        Specifies the path to the executable.
    .PARAMETER ArgumentList
        Specifies the array of arguments to be passed to the executable.
    .PARAMETER RunAs
        Specifies to use 'runas' to use elevated privileges.
    .PARAMETER Activity
        Specifies to use verbose output to user.
    .PARAMETER ContinueExitCodes
        Specifies key/value pair of allowed non-zero exit codes and description for them.
    .PARAMETER LogPath
        Specifies the path where log file should be saved.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [String] $FilePath,
        [Parameter(Position = 1)]
        [Alias('Args')]
        [String[]] $ArgumentList,
        [Parameter(ParameterSetName = 'UseShellExecute')]
        [Switch] $RunAs,
        [Alias('Msg')]
        [String] $Activity,
        [Alias('cec')]
        [Hashtable] $ContinueExitCodes,
        [Parameter(ParameterSetName = 'Default')]
        [Alias('Log')]
        [String] $LogPath
    )
    if ($Activity) { Write-Host "$Activity " -NoNewline }

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo.FileName = $FilePath
    $Process.StartInfo.Arguments = ($ArgumentList | Select-Object -Unique) -join ' '
    $Process.StartInfo.UseShellExecute = $false

    if ($LogPath) {
        if ($FilePath -match '(^|\W)msiexec($|\W)') {
            $Process.StartInfo.Arguments += " /lwe `"$LogPath`""
        } else {
            $Process.StartInfo.RedirectStandardOutput = $true
            $Process.StartInfo.RedirectStandardError = $true
        }
    }

    if ($RunAs) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.Verb = 'RunAs'
    }

    debug $Process.StartInfo.FileName
    debug $Process.StartInfo.Arguments

    try {
        $Process.Start() | Out-Null
    } catch {
        if ($Activity) { Write-UserMessage -Message 'error.' -Color 'DarkRed' }
        Write-UserMessage -Message $_.Exception.Message -Err
        return $false
    }

    if ($LogPath -and ($FilePath -notmatch '(^|\W)msiexec($|\W)')) {
        Out-File -InputObject $Process.StandardOutput.ReadToEnd() -FilePath $LogPath -Encoding 'ASCII' -Append
    }

    $Process.WaitForExit()

    if ($Process.ExitCode -ne 0) {
        if ($ContinueExitCodes -and ($ContinueExitCodes.ContainsKey($Process.ExitCode))) {
            if ($Activity) {
                Write-Host 'done.' -ForegroundColor 'DarkYellow'
            }
            Write-UserMessage -Message $ContinueExitCodes[$Process.ExitCode] -Warning
            return $true
        } else {
            if ($Activity) { Write-UserMessage -Message 'error.' -Color 'DarkRed' }
            Write-UserMessage -Message "Exit code was $($Process.ExitCode)!" -Err
            return $false
        }
    }
    if ($Activity) { Write-Host 'done.' -ForegroundColor 'Green' }

    return $true
}

function dl($url, $to) {
    $wc = New-Object System.Net.Webclient
    $wc.headers.add('Referer', (strip_filename $url))
    $wc.Headers.Add('User-Agent', (Get-UserAgent))
    $wc.downloadFile($url, $to)
}

function env($name, $global, $val = '__get') {
    $target = if ($global) { 'Machine' } else { 'User' }
    if ($val -eq '__get') {
        [System.Environment]::GetEnvironmentVariable($name, $target)
    } else {
        [System.Environment]::SetEnvironmentVariable($name, $val, $target)
    }
}

function isFileLocked([string]$path) {
    $file = New-Object System.IO.FileInfo $path

    if ((Test-Path -Path $path) -eq $false) { return $false }

    try {
        $stream = $file.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        if ($stream) { $stream.Close() }

        return $false
    } catch {
        # File is locked by a process
        return $true
    }
}

function is_directory([String] $path) { return (Test-Path $path) -and (Get-Item $path) -is [System.IO.DirectoryInfo] }

# Move content of directory into different directory
function movedir {
    [CmdletBinding()]
    param ($from, $to)

    $from = $from.TrimEnd('\')
    $parent = Split-Path $from -Parent
    $to = $to.TrimEnd('\')

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = 'robocopy.exe'
    $proc.StartInfo.Arguments = "`"$from`" `"$to`" /e /move"
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc.Start()
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()

    if ($proc.ExitCode -ge 8) {
        debug $out
        throw [ScoopException] "Decompress Error|-Could not find '$(fname $from) in $parent'! (error $($proc.ExitCode))" # TerminatingError thrown
    }

    # Wait for robocopy to terminate its threads
    1..10 | ForEach-Object {
        if (Test-Path $from) { Start-Sleep -Milliseconds 100 }
    }
}

function get_app_name($path) {
    if ($path -match '([^/\\]+)[/\\]current[/\\]') {
        return $matches[1].ToLower()
    }

    return ''
}

function get_app_name_from_ps1_shim($shim_ps1) {
    if (!(Test-Path($shim_ps1))) { return '' }

    $content = (Get-Content $shim_ps1 -Encoding utf8) -join ' '

    return get_app_name $content
}

function warn_on_overwrite($shim_ps1, $path) {
    if (!(Test-Path($shim_ps1))) { return }

    $shim_app = get_app_name_from_ps1_shim $shim_ps1
    $path_app = get_app_name $path
    if ($shim_app -eq $path_app) { return }

    $filename = [System.IO.Path]::GetFileName($path)
    Write-UserMessage -Message "Overwriting shim to $filename installed from $shim_app" -Warning
}

function shim($path, $global, $name, $arg) {
    if (!(Test-Path $path)) { throw [ScoopException] "Shim creation fail|-Cannot shim '$(fname $path)': could not find '$path'" } # TerminatingError thrown

    $abs_shimdir = shimdir $global | ensure
    if (!$name) { $name = strip_ext (fname $path) }

    $shim = Join-Path $abs_shimdir $name.ToLower()

    warn_on_overwrite "$shim.ps1" $path

    # convert to relative path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path $path -Relative
    Pop-Location
    $resolved_path = Resolve-Path $path

    #region PS1 shim
    # if $path points to another drive resolve-path prepends .\ which could break shims
    if ($relative_path -match '^(.\\[\w]:).*$') {
        Out-UTF8File -Path "$shim.ps1" -Content "`$path = `"$path`""
    } else {
        # Setting PSScriptRoot in Shim if it is not defined, so the shim doesn't break in PowerShell 2.0
        Out-UTF8File -Path "$shim.ps1" -Content @(
            "if (!(Test-Path Variable:PSScriptRoot)) { `$PSScriptRoot = Split-Path `$MyInvocation.MyCommand.Path -Parent }"
            "`$path = Join-Path `"`$PSScriptRoot`" `"$relative_path`""
        )
    }

    if ($path -match '\.jar$') {
        "if(`$MyInvocation.ExpectingInput) { `$input | & java -jar `$path $arg @args } else { & java -jar `$path $arg @args }" | Out-File "$shim.ps1" -Encoding utf8 -Append
    } else {
        "if(`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }" | Out-File "$shim.ps1" -Encoding 'utf8' -Append
    }
    Add-Content "$shim.ps1" 'exit $LASTEXITCODE' -Encoding 'utf8'
    #endregion PS1 shim

    if ($path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        # TODO: Use relative path from this file
        versiondir 'scoop' 'current' | Join-Path -ChildPath 'supporting\shimexe\bin\shim.exe' | Copy-Item -Destination "$shim.exe" -Force
        $result = @("path = $resolved_path")
        if ($arg) { $result += "args = $arg" }

        Out-UTF8File -Path "$shim.shim" -Content $result
    } elseif ($path -match '\.(bat|cmd)$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        Out-UTF8File -Path "$shim.cmd" -Content "@`"$resolved_path`" $arg %*"
        Out-UTF8File -Path "$shim" -Content "#!/bin/sh`nMSYS2_ARG_CONV_EXCL=/C cmd.exe /C `"$resolved_path`" $arg `"$@`""
    } elseif ($path -match '\.ps1$') {
        # make ps1 accessible from cmd.exe
        "@echo off
setlocal enabledelayedexpansion
set args=%*
:: replace problem characters in arguments
set args=%args:`"='%
set args=%args:(=``(%
set args=%args:)=``)%
set invalid=`"='
if !args! == !invalid! ( set args= )
powershell -noprofile -ex unrestricted `"& '$resolved_path' $arg %args%;exit `$LASTEXITCODE`"" | Out-File "$shim.cmd" -Encoding 'Ascii'

        "#!/bin/sh`npowershell.exe -noprofile -ex unrestricted `"& '$resolved_path'`" $arg `"$@`"" | Out-File $shim -Encoding 'Ascii'
    } elseif ($path -match '\.jar$') {
        "@java -jar `"$resolved_path`" $arg %*" | Out-File "$shim.cmd" -Encoding 'Ascii'
        "#!/bin/sh`njava -jar `"$resolved_path`" $arg `"$@`"" | Out-File $shim -Encoding 'Ascii'
    }
}

function search_in_path($target) {
    $path = (env 'PATH' $false) + ';' + (env 'PATH' $true)
    foreach ($dir in $path.Split(';')) {
        if (Test-Path "$dir\$target" -PathType 'Leaf') {
            return Join-Path $dir $target
        }
    }
}

function ensure_in_path($dir, $global) {
    $path = env 'PATH' $global
    if ($path -notmatch [System.Text.RegularExpressions.Regex]::Escape($dir)) {
        Write-UserMessage -Message "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path." -Output

        env 'PATH' $global "$dir;$path" # for future sessions...
        $env:PATH = "$dir;$env:PATH" # for this session
    }
}

function ensure_architecture($architecture_opt) {
    if (!$architecture_opt) { return default_architecture }

    $architecture_opt = $architecture_opt.ToString().ToLower()

    switch ($architecture_opt) {
        { @('64bit', '64', 'x64', 'amd64', 'x86_64', 'x86-64') -contains $_ } { return '64bit' }
        { @('32bit', '32', 'x86', 'i386', '386', 'i686') -contains $_ } { return '32bit' }
        default { throw [System.ArgumentException] "Invalid architecture: '$architecture_opt'" }
    }
}

function Confirm-InstallationStatus {
    <#
    .SYNOPSIS
        Get status of specific applications.
        Returns array of 3 item arrays (appliation name, globally installed, bucket name)
    .PARAMETER Apps
        Specifies the array of applications to be evalueated.
    .PARAMETER Global
        Specifies to check globally installed applications.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String[]] $Apps,
        [Switch] $Global
    )
    $Global | Out-Null # PowerShell/PSScriptAnalyzer#1472
    $installed = @()

    $Apps | Select-Object -Unique | Where-Object -Property 'Name' -NE -Value 'scoop' | ForEach-Object {
        $app, $null, $null = parse_app $_
        $buc = (app_status $app $Global).bucket
        if ($Global) {
            if (installed $app $true) {
                $installed += , @($app, $true, $buc)
            } elseif (installed $app $false) {
                Write-UserMessage -Message "'$app' isn't installed globally, but it is installed for your account." -Err
                Write-UserMessage -Message 'Try again without the --global (or -g) flag instead.' -Warning
            } else {
                Write-UserMessage -Message "'$app' isn't installed." -Err
            }
        } else {
            if (installed $app $false) {
                $installed += , @($app, $false, $buc)
            } elseif (installed $app $true) {
                Write-UserMessage -Message "'$app' isn't installed for your account, but it is installed globally." -Err
                Write-UserMessage -Message 'Try again with the --global (or -g) flag instead.' -Warning
            } else {
                Write-UserMessage -Message "'$app' isn't installed." -Err
            }
        }
    }

    return , $installed
}

function strip_path($orig_path, $dir) {
    if ($null -eq $orig_path) { $orig_path = '' }
    $stripped = [string]::join(';', @( $orig_path.split(';') | Where-Object { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
}

function add_first_in_path($dir, $global) {
    # Future sessions
    $null, $currpath = strip_path (env 'path' $global) $dir
    env 'path' $global "$dir;$currpath"

    # This session
    $null, $env:PATH = strip_path $env:PATH $dir
    $env:PATH = "$dir;$env:PATH"
}

function remove_from_path($dir, $global) {
    # Future sessions
    $was_in_path, $newpath = strip_path (env 'path' $global) $dir
    if ($was_in_path) {
        Write-UserMessage -Message "Removing $(friendly_path $dir) from path." -Output
        env 'path' $global $newpath
    }

    # Current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if ($was_in_path) { $env:PATH = $newpath }
}

function ensure_scoop_in_path($global) {
    $abs_shimdir = shimdir $global | ensure
    # be aggressive (b-e-aggressive) and install scoop first in the path
    ensure_in_path $abs_shimdir $global
}

function ensure_robocopy_in_path {
    if (!(Test-CommandAvailable 'robocopy')) { shim 'C:\Windows\System32\Robocopy.exe' $false }
}

function wraptext($text, $width) {
    if (!$width) { $width = $host.UI.RawUI.BufferSize.Width }
    $width -= 1 # be conservative: doesn't seem to print the last char

    $text -split '\r?\n' | ForEach-Object {
        $line = ''
        $_ -split ' ' | ForEach-Object {
            if ($line.length -eq 0) { $line = $_ }
            elseif ($line.length + $_.length + 1 -le $width) { $line += " $_" }
            else { $lines += , $line; $line = $_ }
        }
        $lines += , $line
    }

    $lines -join "`n"
}

function pluralize($count, $singular, $plural) {
    if ($count -eq 1) { $singular } else { $plural }
}

# convert list of apps to list of ($app, $global, $bucket) tuples
function applist($apps, $global, $bucket = $null) {
    if (!$apps) { return @() }
    return , @($apps | ForEach-Object { , @($_, $global, $bucket) })
}

function parse_app([string] $app) {
    # TODO: YAML
    # if ($app -match "(?:(?<bucket>[a-zA-Z0-9-]+)\/)?(?<app>.*\.$ALLOWED_MANIFESTS_EXTENSIONS_REGEX$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?") {
    if ($app -match '(?:(?<bucket>[a-zA-Z0-9-.]+)\/)?(?<app>.*.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?') {
        return $matches['app'], $matches['bucket'], $matches['version']
    }
    return $app, $null, $null
}

function show_app($app, $bucket, $version) {
    if ($bucket) { $app = "$bucket/$app" }
    if ($version) { $app = "$app@$version" }

    return $app
}

function last_scoop_update() {
    $lastUpdate = Invoke-ScoopCommand 'config' @{ 'name' = 'lastupdate' }

    if ($null -ne $lastUpdate) {
        try {
            $lastUpdate = Get-Date ($lastUpdate.Substring(4))
        } catch {
            Write-UserMessage -Message 'Config: Incorrect update date format' -Info
            $lastUpdate = $null
        }
    }

    return $lastUpdate
}

function is_scoop_outdated() {
    $lastUp = last_scoop_update
    $now = Get-Date
    $res = $true

    if ($null -eq $lastUp) {
        Invoke-ScoopCommand 'config' @{ 'name' = 'lastupdate'; 'value' = ($now.ToString($UPDATE_DATE_FORMAT)) } | Out-Null
    } else {
        $res = $lastUp.AddHours(3) -lt $now.ToLocalTime()
    }

    return $res
}

function Invoke-VariableSubstitution {
    <#
    .SYNOPSIS
        Substitute (find and replace) provided parameters in provided entity.
    .PARAMETER Entity
        Specifies the entity to be substituted (searched in).
    .PARAMETER Substitutes
        Specifies the hashtable providing name and value pairs for "find and replace".
        Hashtable keys should start with $ (dollar sign). Curly bracket variable syntax will be substituted automatically.
    .PARAMETER EscapeRegularExpression
        Specifies to escape regular expressions before replacing values.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [AllowNull()]
        $Entity,
        [Parameter(Mandatory)]
        [Alias('Parameters')]
        [HashTable] $Substitutes,
        [Switch] $EscapeRegularExpression
    )

    process {
        $EscapeRegularExpression | Out-Null # PowerShell/PSScriptAnalyzer#1472
        $newEntity = $Entity

        if ($null -ne $newEntity) {
            switch ($newEntity.GetType().Name) {
                'String' {
                    $Substitutes.GetEnumerator() | ForEach-Object {
                        $value = if (($EscapeRegularExpression -eq $false) -or ($null -eq $_.Value)) { $_.Value } else { [Regex]::Escape($_.Value) }
                        $curly = '${' + $_.Name.TrimStart('$') + '}'

                        $newEntity = $newEntity.Replace($curly, $value)
                        $newEntity = $newEntity.Replace($_.Name, $value)
                    }
                }
                'Object[]' {
                    $newEntity = $newEntity | ForEach-Object { Invoke-VariableSubstitution -Entity $_ -Substitutes $Substitutes -EscapeRegularExpression:$regexEscape }
                }
                'PSCustomObject' {
                    $newentity.PSObject.Properties | ForEach-Object { $_.Value = Invoke-VariableSubstitution -Entity $_ -Substitutes $Substitutes -EscapeRegularExpression:$regexEscape }
                }
                default {
                    # This is not needed, but to cover all possible use cases explicitly
                    $newEntity = $newEntity
                }
            }
        }

        return $newEntity
    }
}

# TODO: Deprecate
function substitute($entity, [Hashtable] $params, [Bool]$regexEscape = $false) {
    return Invoke-VariableSubstitution -Entity $entity -Substitutes $params -EscapeRegularExpression:$regexEscape
}

function format_hash([String] $hash) {
    # Convert base64 encoded hash values
    if ($hash -match '^(?:[A-Za-z\d+\/]{4})*(?:[A-Za-z\d+\/]{2}==|[A-Za-z\d+\/]{3}=|[A-Za-z\d+\/]{4})$') {
        $base64 = $Matches[0]
        if (!($hash -match '^[a-fA-F\d]+$') -and $hash.Length -notin @(32, 40, 64, 128)) {
            try {
                $hash = ([System.Convert]::FromBase64String($base64) | ForEach-Object { $_.ToString('x2') }) -join ''
            } catch {
                $hash = $hash
            }
        }
    }

    $hash = $hash.toLower()

    switch ($hash.Length) {
        32 { $hash = "md5:$hash" } # md5
        40 { $hash = "sha1:$hash" } # sha1
        64 { $hash = $hash } # sha256
        128 { $hash = "sha512:$hash" } # sha512
        default { $hash = $null }
    }

    return $hash
}

function format_hash_aria2([String] $hash) {
    $hash = $hash -split ':' | Select-Object -Last 1

    switch ($hash.Length) {
        32 { $hash = "md5=$hash" } # md5
        40 { $hash = "sha-1=$hash" } # sha1
        64 { $hash = "sha-256=$hash" } # sha256
        128 { $hash = "sha-512=$hash" } # sha512
        default { $hash = $null }
    }

    return $hash
}

function get_hash([String] $multihash) {
    $type, $hash = $multihash -split ':'
    # no type specified, assume sha256
    if (!$hash) { $type, $hash = 'sha256', $multihash }

    if (@('md5', 'sha1', 'sha256', 'sha512') -notcontains $type) {
        return $null, "Hash type '$type' isn't supported."
    }

    return $type, $hash.ToLower()
}

function handle_special_urls($url) {
    # FossHub.com
    if ($url -match '^(?:.*fosshub.com\/)(?<name>.*)(?:\/|\?dwl=)(?<filename>.*)$') {
        $Body = @{
            'projectUri'      = $Matches.name
            'fileName'        = $Matches.filename
            'source'          = 'CF' # Needed since July 2020
            'isLatestVersion' = $true
        }
        if ((Invoke-RestMethod -Uri $url) -match '"p":"(?<pid>[a-f0-9]{24}).*?"r":"(?<rid>[a-f0-9]{24})') {
            $Body.Add('projectId', $Matches.pid)
            $Body.Add('releaseId', $Matches.rid)
        }
        $url = Invoke-RestMethod -Method Post -Uri 'https://api.fosshub.com/download/' -ContentType 'application/json' -Body (ConvertTo-Json $Body -Compress)
        if ($null -eq $url.error) {
            $url = $url.data.url
        }
    }

    # Sourceforge.net
    if ($url -match '(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*?)(?:$|\/download|\?)') {
        # Reshapes the URL to avoid redirections
        $url = "https://downloads.sourceforge.net/project/$($matches['project'])/$($matches['file'])"
    }

    return $url
}

#region Deprecated
function reset_aliases() {
    Show-DeprecatedWarning $MyInvocation 'Reset-Alias'
    Reset-Alias
}

function file_path($app, $file) {
    Show-DeprecatedWarning $MyInvocation 'Get-AppFilePath'
    return Get-AppFilePath -App $app -File $file
}

function run($exe, $arg, $msg, $continue_exit_codes) {
    Show-DeprecatedWarning $MyInvocation 'Invoke-ExternalCommand'
    Invoke-ExternalCommand -FilePath $exe -ArgumentList $arg -Activity $msg -ContinueExitCodes $continue_exit_codes
}

function fullpath($path) {
    Show-DeprecatedWarning $MyInvocation 'Get-AbsolutePath'
    return Get-AbsolutePath -Path $path
}
#endregion Deprecated

##################
# Core Bootstrap #
##################

# Note: Github disabled TLS 1.0 support on 2018-02-23. Need to enable TLS 1.2
#       for all communication with api.github.com
Optimize-SecurityProtocol

# TODO: Drop
$c = get_config 'rootPath'
if ($c) {
    Write-UserMessage -Message 'Configuration option ''rootPath'' is deprecated. Configure ''SCOOP'' environment variable instead' -Err
    if (!$env:SCOOP) { $env:SCOOP = $c }
}

# Path gluing has to remain in these global variables to not fail in case user do not have some environment configured (most likely linux case)
# Scoop root directory
$SCOOP_ROOT_DIRECTORY = $env:SCOOP, "$env:USERPROFILE\scoop" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1

# Scoop global apps directory
$SCOOP_GLOBAL_ROOT_DIRECTORY = $env:SCOOP_GLOBAL, "$env:ProgramData\scoop" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1

# Scoop cache directory
# Note: Setting the SCOOP_CACHE environment variable to use a shared directory
#       is experimental and untested. There may be concurrency issues when
#       multiple users write and access cached files at the same time.
#       Use at your own risk.
$SCOOP_CACHE_DIRECTORY = $env:SCOOP_CACHE, "$SCOOP_ROOT_DIRECTORY\cache" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1

# Load Scoop config
$configHome = $env:XDG_CONFIG_HOME, "$env:USERPROFILE\.config" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1
$SCOOP_CONFIGURATION_FILE = Join-Path $configHome 'scoop\config.json'
$SCOOP_CONFIGURATION = load_cfg $SCOOP_CONFIGURATION_FILE

# TODO: Remove deprecated variables
$scoopdir = $SCOOP_ROOT_DIRECTORY
$globaldir = $SCOOP_GLOBAL_ROOT_DIRECTORY
$cachedir = $SCOOP_CACHE_DIRECTORY
$scoopConfig = $SCOOP_CONFIGURATION
$configFile = $SCOOP_CONFIGURATION_FILE

# Do not use the new native command parsing PowerShell/PowerShell#15239, Ash258/Scoop-Core#142
$PSNativeCommandArgumentPassing = 'Legacy'

# Setup proxy globally
setup_proxy
