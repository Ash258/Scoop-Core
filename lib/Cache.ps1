'core' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Get-CachedFileInfo {
    <#
    .SYNOPSIS
        Parse cached file into psobject with app, version, url and size properties.
    .PARAMETER File
        Specifies the cached file to be parsed.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [System.IO.FileInfo] $File)

    process {
        $app, $version, $url = $File.Name -split '#'
        $size = filesize $File.Length

        return New-Object PSObject -Prop @{ 'app' = $app; 'version' = $version; 'url' = $url; 'size' = $size }
    }
}

function Show-CachedFileList {
    <#
    .SYNOPSIS
        Table representation of cached files including total size.
    .PARAMETER ApplicationFilter
        Specifies to filter only subset of applications.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [String[]] $ApplicationFilter
    )

    process {
        $regex = $ApplicationFilter -join '|'
        if (!$ApplicationFilter) { $regex = '.*?' }

        $files = Get-ChildItem -LiteralPath $SCOOP_CACHE_DIRECTORY -File | Where-Object -Property 'Name' -Match -Value "^($regex)#"
        $totalSize = [double] ($files | Measure-Object -Property 'Length' -Sum).Sum

        $_app = @{ 'Expression' = { "$($_.app) ($($_.version))" } }
        $_url = @{ 'Expression' = { $_.url }; 'Alignment' = 'Right' }
        $_size = @{ 'Expression' = { $_.size }; 'Alignment' = 'Right' }

        $files | ForEach-Object { Get-CachedFileInfo -File $_ } | Format-Table -Property $_size, $_app, $_url -AutoSize -HideTableHeaders
        Write-Output "Total: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalSize)"
    }
}
