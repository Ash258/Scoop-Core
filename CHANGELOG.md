# Changelog

## [0.55](https://github.com/Ash258/Scoop-Core/milestone/2)

### 0.55-pre5

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

### 0.55-pre4

- **update**: Ignore merge commits in update log
- `scoop --version` reports PowerShell version
- **depends**: Correctly detect globally installed dependencies
- **buckets**: Indicate successfull bucket removal
- **buckets**: Indicate inability of bucket removal

### 0.55-pre3

- Sync with upstream/master

### 0.55-pre2

- `scoop search` reimplemented
- **scoop-config**: Fix regression from `--help` addition
- **decompress**: Fix 7zip requirements detection
- **autoupdate**: Added `$headVersion` and `$tailVersion` substitutes

### 0.55.1-pre

- Allow `-h` and `--help` parameters for all scoop commands
- Lots of refactorings

### 0.55-pre - Abort deprecation 🎉

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
