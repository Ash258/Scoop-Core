'core' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

function Invoke-GitCmd {
    <#
    .SYNOPSIS
        Git execution wrapper with -C parameter support.
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
        [Alias('Cmd', 'Action')]
        [String] $Command,
        [String] $Repository,
        [Switch] $Proxy,
        [String[]] $Argument
    )

    begin { $preAction = if ($Repository) { '-C', """$Repository""" } else { @() } }

    process {
        switch ($Command) {
            'CurrentCommit' {
                $action = 'rev-parse'
                $Argument = $Argument + @('HEAD')
            }
            'Update' {
                $action = 'pull'
                $Argument += '--rebase=false'
            }
            'UpdateLog' {
                $preAction += '--no-pager'
                $action = 'log'
                $para = @(
                    '--no-decorate'
                    '--format="tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset"'
                    '--grep="\[\(scoop\|shovel\) skip\]"' # Ignore [scoop skip] [shovel skip]
                    '--grep="^Merge [cb]"' # Ignore merge commits
                    '--invert-grep'
                )
                $Argument = $para + $Argument
            }
            'VersionLog' {
                $preAction += '--no-pager'
                $action = 'log'
                $Argument += '--oneline', '--max-count=1', 'HEAD'
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
        & "$env:ComSpec" /d /c $commandToRun
    }
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
