
function cacheinfo($file) {
    $app, $version, $url = $file.name -split '#'
    $size = filesize $file.length
    return New-Object PSObject -prop @{ 'app' = $app; 'version' = $version; 'url' = $url; 'size' = $size }
}

function show($app) {
    $files = @(Get-ChildItem $SCOOP_CACHE_DIRECTORY | Where-Object -Property 'Name' -Match "^$app")
    $total_length = ($files | Measure-Object length -Sum).sum -as [double]

    $f_app = @{ 'Expression' = { "$($_.app) ($($_.version))" } }
    $f_url = @{ 'Expression' = { $_.url }; 'Alignment' = 'Right' }
    $f_size = @{ 'Expression' = { $_.size }; 'Alignment' = 'Right' }


    $files | ForEach-Object { cacheinfo $_ } | Format-Table $f_size, $f_app, $f_url -AutoSize -HideTableHeaders

    "Total: $($files.length) $(pluralize $files.length 'file' 'files'), $(filesize $total_length)"
}
