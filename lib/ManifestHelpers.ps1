'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "$_.ps1")
}

#region Persistence
function Test-Persistence {
    <#
    .SYNOPSIS
        Persistence check helper for files.
    .DESCRIPTION
        This will save some lines to not always write `if (!(Test-Path "$persist_dir\$file")) { New-item "$dir\$file" | Out-Null }` inside manifests.
        variables `$currentFile`, `$filePersistPath`, `$fileDirPath` are exposed and could be used inside `Execution` block.
    .PARAMETER File
        Specifies the file to be checked.
        Do not prefix with $dir. All files are already checked against $dir and $persist_dir.
    .PARAMETER Content
        Specifies the content/value of the created file. Value should be array of strings or string.
    .PARAMETER Execution
        Specifies custom scriptblock to run when file is not persisted.
        https://github.com/lukesampson/scoop-extras/blob/a84b257fd9636d02295b48c3fd32826487ca9bd3/bucket/ditto.json#L25-L33
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String[]] $File,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Object[]] $Content,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ScriptBlock] $Execution
    )

    process {
        for ($ind = 0; $ind -lt $File.Count; ++$ind) {
            $currentFile = $File[$ind]
            $filePersistPath = Join-Path $persist_dir $currentFile
            $fileDirPath = Join-Path $dir $currentFile

            if (!(Test-Path -LiteralPath $filePersistPath -PathType Leaf)) {
                if ($Execution) {
                    & $Execution
                } else {
                    # Handle edge case when there is only one file and multiple contents caused by
                    # If `Test-Persistence alfa.txt @('new', 'beta')` is used,
                    # Powershell will bind Content as simple array with 2 values instead of Array with nested array with 2 values.
                    if (($File.Count -eq 1) -and ($Content.Count -gt 1)) {
                        $cont = $Content
                    } elseif ($ind -lt $Content.Count) {
                        $cont = $Content[$ind]
                    } else {
                        $cont = $null
                    }

                    # File needs to be precreated in case of nested directories
                    New-Item -Path $fileDirPath -ItemType File -Force | Out-Null
                    if ($cont) { Out-UTF8File -Path $fileDirPath -Value $cont }
                }
            }
        }
    }
}

function Copy-ToPersist {
    <#
    .SYNOPSIS
        Manually "persist" file.
    .PARAMETER Item
        Specifies the items to be copied from $dir into $persist_dir
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo[]] $Item
    )
    begin { ensure $persist_dir | Out-Null }

    process {
        Get-ChildItem -Path "$dir\*" -Include $Item -Force | Copy-Item -Destination $persist_dir -Force
    }
}

function Copy-FromPersist {
    <#
    .SYNOPSIS
        Manually "persist" file.
    .PARAMETER Item
        Specifies the items to be copied from $persist_dir into $dir
    #>
    [CmdletBinding()]
    [SupportsWildcards()]
    param([Parameter(Mandatory, ValueFromPipeline)] [System.IO.FileInfo[]] $Item)

    begin { ensure $persist_dir | Out-Null }

    process {
        Get-ChildItem -Path "$persist_dir\*" -Include $Item -Force | Copy-Item -Destination $dir -ErrorAction SilentlyContinue -Force
    }
}
#endregion Persistence

function Remove-AppDirItem {
    <#
    .SYNOPSIS
        Removes the given item from application directory.
        Wildcards are supported.
    .PARAMETER Item
        Specifies the item for removing from $dir.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [System.IO.FileInfo[]] $Item
    )

    process {
        # GCI is not suitable as it do not support nested folder with include
        foreach ($it in $Item) {
            Join-Path $dir $it | Remove-Item -ErrorAction SilentlyContinue -Force -Recurse
        }
    }
}

function Edit-File {
    <#
    .SYNOPSIS
        Finds and replaces text in given file.
    .PARAMETER File
        Specifies the file, which will be loaded.
        File could be passed as full path (used for changing files outside $dir) or just relative path to $dir.
    .PARAMETER Find
        Specifies the string to be replaced.
    .PARAMETER Replace
        Specifies the string for replacing all occurrences.
        Empty string is default => Found string will be removed.
    .PARAMETER Regex
        Specifies if regular expression should be used instead of simple match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo] $File,
        [Parameter(Mandatory)]
        [String[]] $Find,
        [String[]] $Replace,
        [Switch] $Regex
    )

    begin {
        # Use file from $dir
        if (Join-Path $dir $File | Test-Path -PathType Leaf) { $File = Join-Path $dir $File }
    }

    process {
        if (!(Test-Path $File)) {
            Write-UserMessage -Message "File '$File' does not exist" -Err
            return
        }

        $content = Get-Content $File

        for ($i = 0; $i -lt $Find.Count; ++$i) {
            $toFind = $Find[$i]
            if (!$Replace -or ($null -eq $Replace[$i])) {
                $toReplace = ''
            } else {
                $toReplace = $Replace[$i]
            }

            if ($Regex) {
                $content = $content -replace $toFind, $toReplace
            } else {
                $content = $content.Replace($toFind, $toReplace)
            }
        }

        Out-UTF8File -Path $File -Value $content
    }
}

function New-JavaShortcutWrapper {
    <#
    .SYNOPSIS
        Creates new shim-like batch file wrapper to spawn jar files within start menu (using shortcut).
    .PARAMETER FileName
        Specifies the jar executable filename without .jar extension.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] [System.IO.FileInfo[]] $FileName)

    process {
        foreach ($f in $FileName) {
            (Join-Path $dir "$f.bat") | Out-UTF8Content -Value "@start javaw.exe -jar `"%~dp0$f.jar`" %*"
        }
    }
}
