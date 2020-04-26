@{
    Severity = @('Error','Warning')

    ExcludeRules = @(
        # Currently Scoop widely uses Write-Host to output colored text.
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingWriteHost',
        # Temporarily allow uses of Invoke-Expression,
        # this command is used by some core functions and hard to be removed.
        'PSAvoidUsingInvokeExpression',
        # PSUseDeclaredVarsMoreThanAssignments doesn't currently work due to:
        # https://github.com/PowerShell/PSScriptAnalyzer/issues/636
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
