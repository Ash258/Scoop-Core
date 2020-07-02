@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        # Currently Scoop widely uses Write-Host to output colored text.
        'PSAvoidUsingWriteHost',
        # Temporarily allow uses of Invoke-Expression,
        # this command is used by some core functions and hard to be removed.
        'PSAvoidUsingInvokeExpression',
        # PSUseDeclaredVarsMoreThanAssignments doesn't currently work due to:
        # https://github.com/PowerShell/PSScriptAnalyzer/issues/636
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
