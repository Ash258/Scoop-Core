
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
    .PARAMETER Success
        Specifies the output will not contains severity prefix.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromRemainingArguments, Position = 0)]
        [AllowEmptyString()]
        [String[]] $Message,
        [ValidateSet('Message', 'Info', 'Warning', 'Error', 'Success')]
        [String] $Severity = 'Message',
        [Switch] $Output,
        [Switch] $Info,
        [Switch] $Warning,
        [Switch] $Err,
        [Switch] $Success,
        [Switch] $SkipSeverity,
        [System.ConsoleColor] $Color = 'White'
    )
    if ($Info) { $Severity = 'Info' }
    if ($Warning) { $Severity = 'Warning' }
    if ($Err) { $Severity = 'Error' }
    if ($Success) { $Severity = 'Success' }

    switch ($Severity) {
        'Info' { $sev = 'INFO '; $foreColor = 'DarkGray' }
        'Warning' { $sev = 'WARN '; $foreColor = 'DarkYellow' }
        'Error' { $sev = 'ERROR '; $foreColor = 'DarkRed' }
        'Success' { $sev = ''; $foreColor = 'DarkGreen' }
        default {
            $sev = ''
            $foreColor = 'White'
            if ($Color) {
                $foreColor = $Color
            } else {
                $Output = $true
            }
        }
    }

    $m = if ($SkipSeverity) { $Message } else { $Message -replace '^', "$Sev" }
    $display = $m -join "`r`n"
    if ($Output) {
        Write-Output $display
    } else {
        Write-Host $display -ForegroundColor $foreColor
    }
}
