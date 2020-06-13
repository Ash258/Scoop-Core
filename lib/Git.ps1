'core' | ForEach-Object {
    . "$PSScriptRoot\$_.ps1"
}

function Invoke-GitCmd {
    <#
    .SYNOPSIS
        Git execution wrapper support -C parameter.
    .PARAMETER Command
        Specifies git command to execute.
    .PARAMETER Repository
        Specifies fullpath to git repository.
    .PARAMETER Proxy
        Specifies the command needs proxy or not.
    .PARAMETER Argument
        Specifies additional arguments, which should be used.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $Command,
        [String] $Repository,
        [Switch] $Proxy,
        [String[]] $Argument
    )

    $preAction = if ($Repository) { '-C', """$Repository""" } else { @() }

    switch ($Command) {
        'Clone' { $action = 'clone' }
        'Checkout' { $action = 'checkout' }
        'Fetch' { $action = 'fetch' }
        'Ls-Remote' { $action = 'ls-remote' }
        'Update' {
            $action = 'pull'
            $Argument += '--rebase=false'
        }
        'Updatelog' {
            $preAction += '--no-pager'
            $action = 'log'
            $Argument += '--oneline', 'HEAD', '-n', '1'
        }
        default { $action = $Command }
    }

    $commandToRun = 'git', ($preAction -join ' '), $action, ($Argument -join ' ') -join ' '

    if ($Proxy) {
        $prox = get_config 'proxy' 'none'

        # TODO: Drop comspec
        if ($prox -and ($prox -ne 'none')) { $commandToRun = "SET HTTPS_PROXY=$prox && SET HTTP_PROXY=$prox && $commandToRun" }
    }

    debug $commandToRun

    # TODO: Drop comspec
    & "$env:ComSpec" /c $commandToRun
}

#region Deprecated
function git_proxy_cmd {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command @args -Proxy
}

function git_clone {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command 'Clone' -Argument $args -Proxy
}

function git_ls_remote {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command 'ls-remote' -Argument $args -Proxy
}

function git_pull {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command 'Update' -Argument $args -Proxy
}

function git_fetch {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command 'fetch' -Argument $args -Proxy
}

function git_checkout {
    Show-DeprecatedWarning $MyInvocation 'Invoke-GitCmd'
    Invoke-GitCmd -Command 'checkout' -Argument $args -Proxy
}
#endregion Deprecated
