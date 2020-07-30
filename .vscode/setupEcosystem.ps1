#!/usr/bin/env pwsh
param($Folder)

$REPOSITORIES = @(
    @('Ash258/Scoop-Ash258.git', 'Ash258'),
    @('Ash258/Scoop-Core', 'CORE'),
    @('lukesampson/scoop-extras.git', 'Extras', 'Ash258/Scoop-Extras.git'),
    @('Ash258/GenericBucket', 'GenericBucket'),
    @('Ash258/Scoop-GithubActions', 'GithubActions'),
    @('Ash258/GithubActionsBucketForTesting', 'GithubActionsBucketForTesting'),
    @('Ash258/Scoop-JetBrains.git', 'JetBrains'),
    @('Ash258/Scoop-Licenses.git', 'Licenses'),
    @('ScoopInstaller/Main.git', 'Main', 'Ash258/Scoop-Main.git'),
    @('Ash258/Scoop-Sysinternals.git', 'Sysinternals'),
    @('Ash258/Scoop-NirSoft.git', 'NirSoft'),
    @('ScoopInstaller/PHP.git', 'PHP', 'Ash258/Scoop-PHP.git')
)

$GH = 'git@github.com:'

$ind = 0
foreach ($repo in $REPOSITORIES) {
    ++$ind
    Write-Progress -Activity 'Clonning' -Status $repo[0] -PercentComplete ($ind * (100/$REPOSITORIES.Count))
    Write-Host -f green ($ind * (100/$REPOSITORIES.Count))
    $origin = $targetname = $Ash = $target = $null

    $origin = $GH + $repo[0]
    $targetname = $repo[1]
    $Ash = $repo[2]

    $target = Join-Path $Folder $targetname

    git clone $origin $target
    if ($Ash) { git -C $target remote add Ash "$GH$Ash" }
    git fetch --all
}
