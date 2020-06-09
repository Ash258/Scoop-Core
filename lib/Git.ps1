'core' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

Invoke-GitCmd {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateSet('Clone', 'Checkout', 'Fetch', 'Pull', 'Ls-Remote')]
        [String] $Command,
        [String] $Repository,
        [Switch] $Proxy,
        [String[]] $Argument
    )

    switch ($Command) {
        'Clone' { $action = 'clone' }
        'Checkout' { $action = 'checkout' }
        'Fetch' { $action = 'fetch' }
        'Pull' { $action = 'pull --rebase=false' }
        'Ls-Remote' { $action = 'ls-remote' }
        default { $action = $Command }
    }

    $minusC = if ($Repository) { "-C $Repository " } else { '' }
    $additionalArgs = $Argument -join ' '
    $commandToRun = "git $minusC$action $additionalArgs"

    if ($Proxy) {
        $prox = get_config 'proxy'

        # TODO: Drop comspec
        if ($prox -and ($prox -ne 'none')) { $commandToRun = "SET HTTPS_PROXY=$proxy && SET HTTP_PROXY=$proxy && $commandToRun" }
    }

    debug $commandToRun

    # TODO: Drop comspec
    & "$env:ComSpec" /c $commandToRun
}

function git_proxy_cmd {
    $proxy = get_config 'proxy'
    $cmd = "git $($args | ForEach-Object { "$_ " })"
    if ($proxy -and $proxy -ne 'none') {
        $cmd = "SET HTTPS_PROXY=$proxy&&SET HTTP_PROXY=$proxy&&$cmd"
    }
    & "$env:COMSPEC" /c $cmd
}

function git_clone {
    git_proxy_cmd clone $args
}

function git_ls_remote {
    git_proxy_cmd ls-remote $args
}

function git_pull {
    git_proxy_cmd pull --rebase=false $args
}

function git_fetch {
    git_proxy_cmd fetch $args
}

function git_checkout {
    git_proxy_cmd checkout $args
}
