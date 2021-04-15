'core' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Get-CachedFileInfo([System.IO.FileInfo] $File) {
    $app, $version, $url = $File.Name -split '#'
    $size = filesize $File.Length

    return New-Object PSObject -Prop @{ 'app' = $app; 'version' = $version; 'url' = $url; 'size' = $size }
}

function Show-CachedFileList {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [String[]] $Application
    )

    process {
        $regex = $Application -join '|'
        if (!$Application) { $regex = '.*?' }

        $files = Get-ChildItem $SCOOP_CACHE_DIRECTORY | Where-Object -Property 'Name' -Match -Value "^($regex)#"
        $totalSize = [double] ($files | Measure-Object -Property 'Length' -Sum).Sum

        $_app = @{ 'Expression' = { $_.app, ' (', $_.version, ')' -join '' } }
        $_url = @{ 'Expression' = { $_.url }; 'Alignment' = 'Right' }
        $_size = @{ 'Expression' = { $_.size }; 'Alignment' = 'Right' }

        $files | ForEach-Object { Get-CachedFileInfo $_ } | Format-Table -Property $_size, $_app, $_url -AutoSize -HideTableHeaders
        Write-Output "Total: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalSize)"
    }
}
