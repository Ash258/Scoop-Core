# Changelog

## [0.6](https://github.com/Ash258/Scoop-Core/milestone/4)

### 0.6-pre3

- **format**: Always convert forward slashes into backslashes in persist property
- **scoop-utils**: Use correct name of `checkurls` utility
- **Completion**: Respect `SCOOP_CACHE` environment for `cache rm` completion
- **scoop-cache**: Allow multiple apps to be passed as argument
- **scoop-(un)hold**: Detect and show error when global option is missing for globally installed application
- **Core**: Use `Legacy` command argument passing
- **Autoupdate**: Archive old versions of manifest when executing checkver/autoupdate
- **Git**: Always use `--no-pager` option
- **scoop-checkup**: Test Windows Defender exlusions only when executed with administrator privileges
- Remove automatic config migration
- **Config**: Do not support `rootPath`, `globalPath`, `cachePath` config options
- **checkver**:
    - Prevent hitting GitHub rate limits
        - GitHub checkver will use `api.github.com/repos` and github token from environment `GITHUB_TOKEN` or config option `githubToken`
    - Properly reflect execution issues with exit code

### 0.6-pre2

- **scoop-search**: Fix search without parameter provided
- New command `utils` added
- Native parameter binding for aliases works again
- **git**: Fix proxy handling
- **psmodules**: Add global modules to path only if global manifest is installed
- **decompress**: Support `INNOSETUP_USE_INNOEXTRACT` config option and `Expand-InnoArchive -UseInnoextract`
- **format**: Extract checkver fixes into own function and add generic adjust property function
- **schema**
    - Add `disable` property to `checkver` and `autoupdate`
        - `-Force` will ignore this property
    - Remove deprecated short properties
    - Cleanup descriptions
- Remove deprecated functions from code-base
- **binaries**: Indicate binary execution errors with exit codes
- Git operations with custom wrapper are now executable under Unix-like systems
- **auto-pr**
    - Use `main` branch instead of `master` if `remotes/origin/main` exists
    - Require `-Upstream` only when `-Request` is provided
    - Scoop proxy configuration will be used for git calls
    - Call native `git` command instead of `hub` for push operation
    - Refactor all git/hub calls to use -C option
- **scoop-checkup**:
    - Check for main branches adoption (if supported)
    - Check for full shovel adoption
- **scoop-alias**: First alias addition is correctly registered and created
- **autoupdate**: Do not autoupdate unless URL is accessible after successful hash extraction

### 0.6-pre1

- Support YAML typed manifests in some commands
- **virustotal**: Command now works again with V3 API
    - Requires Api key for all operations
- **decompress**: Add `Expand-ZstdArchive` function for extracting standalone zstd archives
- **scoop-install**: Allow modules to be installed globally
- **scoop-install**: Prevent repeated installation of same manifest/url/local file
- **binaries**: Support YAML typed manifests
- General code cleanup and documentation tweaks

## [0.5.5](https://github.com/Ash258/Scoop-Core/milestone/2)

### 0.5.5-pre5

- **manifests**: Introduce manifest helpers to avoid repeating lines in manifests
    - `Assert-Administrator`, `Assert-WindowsMinimalVersion`, `Assert-ScoopConfigValue`, `Test-Persistence`, `Edit-File`, `Remove-AppDirItem`, `New-JavaShortcutWrapper`
- **install**
    - Remove mutually exclusivity of `installer.script` and `installer.file`
        - `script` property is executed after `file`
    - Fix `installer.file` exit code from ps1 scripts
    - Fix `installer.keep` inconsitency between powershell scripts and executables
- **manifests**: Present `pre_download` property
- **scoop-install**: Fix installlation of different/older versions
- **scoop-info**: Respect NO_JUNCTION config
- Add changelog to repository
- **autoupdate**: Initial preparations for array support
- **manifests**: Add `changelog` property
    - It will be shown on manifest installation/updates also in `scoop info` output
- **scoop-alias**: Add `path` and `edit` subcommands
- **completion**: Correctly support `&&` and `||`
- **scoop-(un)hold**: Support `--global` parameter
- **persist**: Pre-create nested directories
- **autoupdate**: Support base64 for all extraction types
- Small code cleanup and refactorings

### 0.5.5-pre4

- **update**: Ignore merge commits in update log
- `scoop --version` reports PowerShell version
- **depends**: Correctly detect globally installed dependencies
- **buckets**: Indicate successfull bucket removal
- **buckets**: Indicate inability of bucket removal

### 0.5.5-pre3

- Sync with upstream/master

### 0.5.5-pre2

- `scoop search` reimplemented
- **scoop-config**: Fix regression from `--help` addition
- **decompress**: Fix 7zip requirements detection
- **autoupdate**: Added `$headVersion` and `$tailVersion` substitutes

### 0.5.5-pre1

- Allow `-h` and `--help` parameters for all scoop commands
- Lots of refactorings

### 0.5.5-pre - Abort deprecation 🎉

- `abort` funcion completely eliminated
    - Multiple manifest installation is not broken in case of one failure. (for example)
- **lint**: Code fixes

## 0.5.2 - Shim fixes

- Always return correct exit code from `.ps1` shim
- Support spaces in shim paths
- Fix error in case of no aliases defined while running `scoop alias list`

## 0.5.1 - Completion tweaks

- Clink completion
- PowerShell completion fixes
    - Virustotal application completion
- Lint

## 0.5.0.1

- Fosshub downloads hotfix

## [0.5 - Fork initializaiton](https://github.com/Ash258/Scoop-Core/milestone/1)

- Licensed under `GPL-3.0-only`

### Commands

- `scoop cat`
- `scoop download`
- `scoop config show`
- `scoop hold|unhold --global` support
- `scoop info`: Handle architecture specific `env_set` and `env_add_path`
- `scoop uninstall|update`: Shows PIDs of running process blocking uninstallation
- `scoop list`: Added `reverse`, `installed`, `updated` options
- `scoop config`: All supported configuration options are listed in help

### Binaries

- `formatjson`: Sort properties and do some automatic fixes

### Manifests

- `pre|post` uninstaller scripts added
- `version`, `description`, `homepage`, `license` properties are required

### General quality of life changes

- Native shell (tab) completion for PowerShell
- License is shown on installation/update
- Source bucket of manifest is shown on installation
- Git operations no longer change user context
- Nongit buckets are not updated == invalid repository error will not be shown
- Update log will not show commits with `[scoop skip]` or `[shovel skip]` in title
- Refactored handling of manifests versions
- Exit codes are handled in a saner way
    - See `scoop --help` for used exit codes
- Internal application files are not using generic name
    - `install.json` -> `scoop-install.json`
    - `manifest.json` -> `scoop-manifest.json`
- System bitness is determined by integer pointer size
    - This allows to install 32bit applications automatically from 32bit shell
- Code cleanup
    - Scoop is no longer called externally in codebase
    - "Better" Linux support

### Autoupdate

- Curly brackets substitution support
- Additional variable debugging
- Pages are now saved into files when debug is enabled
