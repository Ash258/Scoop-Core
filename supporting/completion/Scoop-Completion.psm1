if (Test-Path Function:\TabExpansion) { Rename-Item Function:\TabExpansion Invoke-DefaultTabExpansion }

function Expand-Tab($Line, $Word) {
    $block = [Regex]::Split($Line, '[|;]')[-1].TrimStart()

    switch -Regex ($block) {
        # TODO:

        default {
            Invoke-DefaultTabExpansion $Line $Word
        }
    }
}

Export-ModuleMember -Function 'Expand-Tab'
