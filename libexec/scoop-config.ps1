# Usage: scoop config [<SUBCOMMAND>] [<OPTIONS>] [<NAME> [<VALUE>]]
# Summary: Get or set configuration values into scoop configuration file.
# Help: The scoop configuration file is located at ~/.config/scoop/config.json
#
# To get a configuration setting:
#   scoop config <NAME>
#
# To set a configuration setting:
#   scoop config <NAME> <VALUE>
#
# To remove a configuration setting:
#   scoop config rm <NAME>
#
# To show full configuration file:
#   scoop config show
# or:
#   scoop config
#
# Subcommands:
#   rm              Remove specified configuration option from configuration file.
#   show            Show full configuration file in plain form (json). Default subcommand when none is provided.
#
# Options:
#   -h, --help      Show help for this command.
#
# Settings
# --------
#
# proxy: [username:password@]host:port
#   By default, Scoop will use the proxy settings from Internet Options, but with anonymous authentication.
#
#       * To use the credentials for the current logged-in user, use 'currentuser' in place of username:password
#       * To use the system proxy settings configured in Internet Options, use 'default' in place of host:port
#       * An empty or unset value for proxy is equivalent to 'default' (with no username or password)
#       * To bypass the system proxy and connect directly, use 'none' (with no username or password)
#
# default-architecture: 64bit|32bit
#   Allows to configure preferred architecture for application installation.
#   If not specified, architecture is determined automatically.
#
# 7ZIPEXTRACT_USE_EXTERNAL: $true|$false
#   External 7zip (from path) will be used for archives extraction.
#
# MSIEXTRACT_USE_LESSMSI: $true|$false
#   Prefer lessmsi utility over native msiexec for installation of msi based installers.
#   This is preferred option and will be default in future.
#
# INNOSETUP_USE_INNOEXTRACT: $true|$false
#   Prefer innoextract utility over innounp for installation of innosetup based installers.
#
# NO_JUNCTIONS: $true|$false
#   The 'current' version alias will not be used.
#   Shims, shortcuts and environment variables will point to specific version instead.
#
# debug: $true|$false
#   Additional output will be shown to identify possible source of problems.
#
# SCOOP_REPO: http://github.com/lukesampson/scoop
#   Git repository containining scoop source code.
#   This configuration is useful for custom tweaked forks.
#
# SCOOP_BRANCH: main|NEW
#   Allow to use different branch than main.
#   Could be used for testing specific functionalities before stable release.
#   If you want to receive updates earlier to test new functionalities use NEW branch.
#
# show_update_log: $true|$false
#   Do not show changed commits on 'scoop update'
#
# virustotal_api_key:
#   API key used for uploading/scanning files using virustotal.
#   See: 'https://support.virustotal.com/hc/en-us/articles/115002088769-Please-give-me-an-API-key'
#
# githubToken:
#   GitHub API token used for checkver/autoupdate runs to prevent rate limiting.
#   See: 'https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token'
#
# ARIA2 configuration
# -------------------
#
# aria2-enabled: $true|$false
#   Aria2c will be used for downloading of artifacts.
#
# aria2-retry-wait: 2
#   Number of seconds to wait between retries.
#   See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-retry-wait'
#
# aria2-split: 5
#   Number of connections used for download.
#   See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-s'
#
# aria2-max-connection-per-server: 5
#   The maximum number of connections to one server for each download.
#   See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-x'
#
# aria2-min-split-size: 5M
#   Downloaded files will be splitted by this configured size and downloaded using multiple connections.
#   See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-k'
#
# aria2-options:
#   Array of additional aria2 options.
#   See: 'https://aria2.github.io/manual/en/html/aria2c.html#options'

'core', 'getopt', 'help', 'Helpers' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

# TODO: Add --global - Ash258/Scoop-Core#5

$ExitCode = 0
$null, $Config, $_err = Resolve-GetOpt $args

if ($_err) { Stop-ScoopExecution -Message "scoop config: $_err" -ExitCode 2 }
if (!$Config) { $Config = @('show') }

$Name = $Config[0]
$Value = $Config[1]

if ($Name -eq 'rm') {
    if (!$Value) { Stop-ScoopExecution -Message 'Parameter <NAME> is required for ''rm'' subcommand' -ExitCode 2 }

    set_config $Value $null | Out-Null
    Write-UserMessage -Message "'$Value' has been removed"
} elseif ($Name -eq 'show') {
    Get-Content $SCOOP_CONFIGURATION_FILE -Raw
} elseif ($null -ne $Value) {
    set_config $Name $Value | Out-Null
    Write-UserMessage -Message "'$Name' has been set to '$Value'"
} else {
    $mes = get_config $Name "'$Name' is not set"
    # TODO: Convert result to json if it is not string

    Write-UserMessage -Message $mes -Output
}

exit $ExitCode
