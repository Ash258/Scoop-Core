# Usage: scoop virustotal [<OPTIONS>] <APP>...
# Summary: Search virustotal database for potential viruses in files provided in manifest(s).
# Help: You can use '*' in place of <APP> to check all installed applications.
#
# The hash of file is also a key to access VirusTotal's scan results.
# This allows to check the safety of the files without even downloading
# them in many cases. If the hash is unknown to VirusTotal, the
# download link is printed and VirusTotal detection is triggered.
#
#   scoop config 'virustotal_api_key' <your API key: 64 lower case hex digits>
#
# Exit codes:
#   0 -> success
#   1 -> problem parsing arguments
#   2 -> at least one package was marked unsafe by VirusTotal
#   4 -> at least one exception was raised while looking for info
#   8 -> at least one package couldn't be queried because its hash type
#        isn't supported by VirusTotal, the manifest couldn't be found
#        or didn't contain a hash
#   Note: the exit codes (2, 4 & 8) may be combined, e.g. 6 -> exit codes
#         2 & 4 combined
#
# Options:
#   -h, --help                Show help for this command.
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the manifest supports it.
#   -s, --scan                For packages where VirusTotal has no information, send download URL
#                             for analysis (and future retrieval). This requires you to configure
#                             your virustotal_api_key (see help entry for config command).
#   -n, --no-depends          By default, all dependencies are checked, too.  This flag allows
#                             to avoid it.

'core', 'depends', 'getopt', 'help', 'VirusTotal' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: --no-depends => --independent
# TODO: Drop --scan??

Reset-Alias

$opt, $apps, $err = getopt $args 'a:sn' 'arch=', 'scan', 'no-depends'
if ($err) { Stop-ScoopExecution -Message "scoop virustotal: $err" -ExitCode 2 }
if (!$apps) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }
if (!$VT_API_KEY) { Stop-ScoopExecution -Message 'Virustotal API Key is required' }

$architecture = ensure_architecture ($opt.a + $opt.arch)
$DoScan = $opt.scan -or $opt.s

if ($apps -eq '*') {
    $apps = installed_apps $false
    $apps += installed_apps $true
}
if (!$opt.n -and !$opt.'no-depends') { $apps = install_order $apps $architecture }

$exitCode = 0

foreach ($app in $apps) {
    # TODO: Adopt Resolve-ManifestInformation
    # Should it take installed manifest or remote manifest?
    $manifest, $bucket = find_manifest $app
    if (!$manifest) {
        $exitCode = $exitCode -bor $VT_ERR.NoInfo
        Write-UserMessage -Message "${app}: manifest not found" -Err
        continue
    }

    foreach ($url in (url $manifest $architecture)) {
        $hash = hash_for_url $manifest $url $architecture

        if (!$hash) {
            Write-UserMessage -Message "${app}: Cannot find hash for $url" -Warning
            continue
        }

        try {
            $exitCode = $exitCode -bor (Search-VirusTotal $hash $app)
        } catch {
            $exitCode = $exitCode -bor $VT_ERR.Exception

            if ($_.Exception.Message -like '*(404)*') {
                Submit-ToVirusTotal -Url $url -App $app -DoScan:$DoScan
            } else {
                if ($_.Exception.Message -match '\(204|429\)') {
                    Write-UserMessage -Message "${app}: VirusTotal request failed: $($_.Exception.Message)"
                    $exitCode = 3
                    continue
                }
                Write-UserMessage -Message "${app}: VirusTotal request failed: $($_.Exception.Message)"
            }
        }
    }
}

exit $exitCode
