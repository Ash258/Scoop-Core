
function Write-UserMessage {
    <#
    .SYNOPSIS
        Print message to the user using Write-Host.
    .DESCRIPTION
        Based on passed severity the message will have different color and prefix.
    .PARAMETER Message
        Specifies the message to be displayed to user.
    .PARAMETER Severity
        Specifies the severity of the message.
        Could be Message, Info, Warning, Error
    .PARAMETER Output
        Specifies the Write-Output cmdlet is used instead of Write-Host
    .PARAMETER Info
        Same as -Severity Info
    .PARAMETER Warning
        Same as -Severity warning
    .PARAMETER Err
        Same as -Severity Error
    .PARAMETER Success
        Same as -Severity Success
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [String[]] $Message,
        [ValidateSet('Message', 'Info', 'Warning', 'Error', 'Success')]
        [String] $Severity = 'Message',
        [Switch] $Output,
        [Switch] $Info,
        [Switch] $Warning,
        [Switch] $Err,
        [Switch] $Success
    )
    if ($Info) { $Severity = 'Info' }
    if ($Warning) { $Severity = 'Warning' }
    if ($Err) { $Severity = 'Error' }
    if ($Success) { $Severity = 'Success' }

    switch ($Severity) {
        'Info' { $sev = 'INFO '; $color = 'DarkGray' }
        'Warning' { $sev = 'WARN '; $color = 'DarkYellow' }
        'Error' { $sev = 'ERROR '; $color = 'DarkRed' }
        'Success' { $sev = ''; $color = 'DarkGreen' }
        default { $sev = ''; $color = 'White'; $Output = $true }
    }

    $display = ($Message -replace '^', "$Sev") -join "`r`n"
    if ($Output) {
        Write-Output $display
    } else {
        Write-Host $display -ForegroundColor $color
    }
}
