# <a href="https://shovel.ash258.com"><img width=32 height=32 src="https://i.imgur.com/NQkgLgu.png"/> ~~Scoop~~ Shovel <a/> [![Build status](https://ci.appveyor.com/api/projects/status/9cso6l446o0ayo8a?svg=true)](https://ci.appveyor.com/project/Ash258/shovel) ![Latest Stable Release)](https://img.shields.io/github/v/release/Ash258/Scoop-Core?color=ffde03&label=Stable&logoColor=ffde03) ![Latest pre-releases)](https://img.shields.io/github/v/release/Ash258/Scoop-Core?color=ffde03&include_prereleases&label=NEW&logoColor=ffde03)

Command-line installer for Windows

## Goals

Scriptable, user-friendly command line installation of applications with a minimal amount of friction.

- Eliminate permission/UAC popup
- Avoid GUI wizard-style installers
    - Use [winget][winget] for interactive installations
- Do not pollute `PATH`
- Skip unexpected side-effects from installing and uninstalling programs
    - Applications installed by scoop usually do not execute application specific installers
        - If you are looking for command line tool for executing application specific installers, refer to [winget][winget] or [chocolatey][choco]
- Dependencies resolving for other scoop installed applications

```powershell
shovel install gsudo
sudo shovel install --global 7zip git openssh
shovel install aria2 curl grep sed less touch
shovel install python ruby go perl
shovel install extras/firefox
```

## Requirements

- Windows 10 / Windows Server 2012+
    - Older systems might work, but will not receive support
- [PowerShell 5](https://aka.ms/wmf5download)
    - [PowerShell 7 should be preferred when possible](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7)
- [.NET Framework 4.7.2](https://www.microsoft.com/net/download)
- PowerShell must be enabled for your user account e.g. `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Installation

[Refer to the new installer to install base scoop.](https://github.com/ScoopInstaller/Install#scoop-uninstaller)

As soon as base scoop is installed do the following:

1. `scoop install 7zip git`
1. `scoop config SCOOP_REPO 'https://github.com/Ash258/Scoop-Core'`
1. `scoop update`
1. `scoop status`
1. `scoop checkup`

Once installed, run `scoop help` for additional information.

## Multi-connection downloads with `aria2`

Shovel can utilize [`aria2`](https://github.com/aria2/aria2) to use multi-connection downloads.
Simply install `aria2` through Shovel and it will be used for all downloads afterward.

```powershell
shovel install aria2
```

Refer to `shovel help config` how to adjust aria2 specific configuration.

## Applications installed by scoop

The applications that install best with Scoop are commonly called "portable" applications: i.e. compressed program files that run stand-alone when extracted and do not have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Shovel supports them too (and their uninstallers).

Shovel is also great at handling single-file programs and PowerShell scripts.
These do not even need to be compressed.
See the [runat](https://github.com/ScoopInstaller/Main/blob/master/bucket/runat.json) package for an example. It is really just a GitHub gist.

## Known application buckets

The following buckets are known to Shovel:

- [main](https://github.com/ScoopInstaller/Main) - Default bucket for the most common command line utilities
- [extras](https://github.com/lukesampson/scoop-extras) - GUI applications
- [nerd-fonts](https://github.com/matthewjberger/scoop-nerd-fonts) - Nerd Fonts
- [nirsoft](https://github.com/Ash258/Scoop-NirSoft) - All [Nirsoft](https://nirsoft.net) utilites
- [java](https://github.com/ScoopInstaller/Java) - Installers for Oracle Java, OpenJDK, Zulu, ojdkbuild, AdoptOpenJDK, Amazon Corretto, BellSoft Liberica, SapMachine and Microsoft
- [jetbrains](https://github.com/Ash258/Scoop-JetBrains) - All [JetBrains](https://www.jetbrains.com/products/) utilities and IDEs
- [sysinternals](https://github.com/Ash258/Scoop-Sysinternals) - All [Sysinternals](https://docs.microsoft.com/en-us/sysinternals/) tools separately
- [nonportable](https://github.com/TheRandomLabs/scoop-nonportable) - Non-portable applications (may require UAC)
- [php](https://github.com/ScoopInstaller/PHP) - Installers for various versions of PHP
- [versions](https://github.com/ScoopInstaller/Versions) - Alternative versions of applications found in known buckets
- [games](https://github.com/Calinou/scoop-games) - Open source/freeware games and game-related tools

[winget]: https://github.com/microsoft/winget-cli
[choco]: https://chocolatey.org/
