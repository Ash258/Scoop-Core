# Scoop

Command-line installer for Windows

## Goals

Scoop installs programs from the command line with a minimal amount of friction.
It tries to eliminate things like:

- Permission popup windows
- GUI wizard-style installers
- Path pollution from installing lots of programs
- Unexpected side-effects from installing and uninstalling programs
- The need to find and install dependencies
- The need to perform extra setup steps to get a working program

Scoop is very scriptable, so you can run repeatable setups to get your environment just the way you like, e.g.:

```powershell
scoop install sudo
sudo scoop install 7zip git openssh --global
scoop install aria2 curl grep sed less touch
scoop install python ruby go perl
```

If you've built software that you'd like others to use, Scoop is an alternative to building an installer (e.g. MSI or InnoSetup) — you just need to zip your program and provide a JSON manifest that describes how to install it.

## Requirements

- Windows 7 SP1+ / Windows Server 2008+
- [PowerShell 5](https://aka.ms/wmf5download) (or later, include [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6)) and [.NET Framework 4.5](https://www.microsoft.com/net/download) (or later)
- PowerShell must be enabled for your user account e.g. `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Installation

[Refer to new installer how to install base scoop.](https://github.com/ScoopInstaller/Install#scoop-uninstaller)

As soon as base scoop is installed do the following:

1. `scoop install 7zip git`
1. `scoop config SCOOP_REPO 'https://github.com/Ash258/Scoop-Core'`
1. `scoop update`

Once installed, run `scoop help` for additional information.

## Multi-connection downloads with `aria2`

Scoop can utilize [`aria2`](https://github.com/aria2/aria2) to use multi-connection downloads.
Simply install `aria2` through Scoop and it will be used for all downloads afterward.

```powershell
scoop install aria2
```

Refer to `scoop help config` how to adjust aria2 specific configuration.

## Applications installed by scoop

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts.
These don't even need to be compressed.
See the [runat](https://github.com/ScoopInstaller/Main/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.

## Known application buckets

The following buckets are known to scoop:

- [main](https://github.com/ScoopInstaller/Main) - Default bucket for the most common command line utilities
- [extras](https://github.com/lukesampson/scoop-extras) - GUI applications
- [games](https://github.com/Calinou/scoop-games) - Open source/freeware games and game-related tools
- [nerd-fonts](https://github.com/matthewjberger/scoop-nerd-fonts) - Nerd Fonts
- [nirsoft](https://github.com/Ash258/Scoop-NirSoft) - All [Nirsoft](https://nirsoft.net) utilites
- [java](https://github.com/ScoopInstaller/Java) - Installers for Oracle Java, OpenJDK, Zulu, ojdkbuild, AdoptOpenJDK, Amazon Corretto, BellSoft Liberica & SapMachine
- [jetbrains](https://github.com/Ash258/Scoop-JetBrains) - Installers for all JetBrains utilities and IDEs
- [sysinternals](https://github.com/Ash258/Scoop-Sysinternals) - All Sysinternals tools separately
- [nonportable](https://github.com/TheRandomLabs/scoop-nonportable) - Non-portable apps (may require UAC)
- [php](https://github.com/ScoopInstaller/PHP) - Installers for most versions of PHP
- [versions](https://github.com/ScoopInstaller/Versions) - Alternative versions of apps found in other buckets
