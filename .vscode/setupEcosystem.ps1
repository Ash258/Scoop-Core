#!/usr/bin/env pwsh
param($Folder, [Switch] $Https)

$REPOSITORIES = @(
    @('Ash258/Scoop-Core', 'CORE'),
    @('Ash258/GenericBucket', 'GenericBucket'),
    @('Ash258/Scoop-GithubActions', 'GithubActions'),
    @('Ash258/Scoop-Dockers', 'Dockers'),
    @('Ash258/Scoop-Vagrants', 'Vagrants'),
    @('Ash258/Scoop-Ash258.git', 'Ash258'),
    @('Ash258/Scoop-NirSoft.git', 'NirSoft'),
    @('Ash258/Scoop-Licenses.git', 'Licenses'),
    @('Ash258/Scoop-JetBrains.git', 'JetBrains'),
    @('Ash258/Scoop-Sysinternals.git', 'Sysinternals'),
    @('Ash258/Scoop-Validator.git', 'Validator'),
    @('Ash258/Scoop-Shim.git', 'Shim'),
    @('ScoopInstaller/PHP.git', 'PHP', 'Ash258/Scoop-PHP.git'),
    @('ScoopInstaller/Main.git', 'Main', 'Ash258/Scoop-Main.git'),
    @('lukesampson/scoop-extras.git', 'Extras', 'Ash258/Scoop-Extras.git'),
    @('Ash258/GithubActionsBucketForTesting', 'GithubActionsBucketForTesting')
)

$GH = 'git@github.com:'
if ($Https) { $GH = 'https://github.com/' }

$ind = 0
foreach ($repo in $REPOSITORIES) {
    ++$ind
    Write-Progress -Activity 'Clonning' -Status $repo[0] -PercentComplete ($ind * (100 / $REPOSITORIES.Count))
    $origin = $targetname = $Ash = $target = $null

    $origin = $GH + $repo[0]
    $targetname = $repo[1]
    $Ash = $repo[2]
    $target = Join-Path $Folder $targetname

    if (!(Test-Path $target)) { git clone $origin $target }
    $alreadyAdded = git -C $target remote get-url --all Ash 2>$null
    if ($Ash -and ($null -eq $alreadyAdded)) { git -C $target remote add 'Ash' "$GH$Ash" }
    git -C $target fetch --all
}
