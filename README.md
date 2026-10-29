[![GitHub Downloads - All Releases](https://img.shields.io/github/downloads/asheroto/Uninstall-Webroot/total?label=release%20downloads)](https://github.com/asheroto/Uninstall-Webroot/releases)
[![Release](https://img.shields.io/github/v/release/asheroto/Uninstall-Webroot)](https://github.com/asheroto/Uninstall-Webroot/releases)
[![GitHub Release Date - Published_At](https://img.shields.io/github/release-date/asheroto/Uninstall-Webroot)](https://github.com/asheroto/Uninstall-Webroot/releases)

[![GitHub Sponsor](https://img.shields.io/github/sponsors/asheroto?label=Sponsor&logo=GitHub)](https://github.com/sponsors/asheroto?frequency=one-time&sponsor=asheroto)
<a href="https://ko-fi.com/asheroto"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Ko-Fi Button" height="20px"></a>
<a href="https://www.buymeacoffee.com/asheroto"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="40px"></a>

# Uninstall Webroot from PowerShell

**Removes Webroot SecureAnywhere (now OpenText Endpoint Protection). Runs the Webroot uninstaller first, then cleans up the services, registry keys, folders and uninstall entries it leaves behind. Still works when the uninstaller is broken or already gone.**

## Table of Contents

-   [Requirements](#requirements)
-   [Features](#features)
-   [Script Functionality](#script-functionality)
-   [Setup](#setup)
    -   [Method 1 - One Line Command (Runs Immediately)](#method-1---one-line-command-runs-immediately)
        -   [Option A: asheroto.com short URL](#option-a-asherotocom-short-url)
        -   [Option B: direct release URL](#option-b-direct-release-url)
    -   [Method 2 - Download Locally and Run](#method-2---download-locally-and-run)
-   [Parameters](#parameters)
    -   [Example Parameters Usage](#example-parameters-usage)
-   [Reading the Result](#reading-the-result)
-   [Troubleshooting](#troubleshooting)
-   [Notes](#notes)

## Requirements

-   Requires PowerShell running with Administrator privileges
-   Must be run interactively unless `-Force` is used, the Webroot uninstall prompt needs a click
-   Compatible with:
    -   Windows 10
    -   Windows 11

## Features

-   Runs the Webroot uninstaller first if it is still on the device
-   Cleans up by hand whatever the uninstaller leaves behind, or everything if the uninstaller is broken or missing
-   Removes services that `sc.exe delete` refuses, by deleting the service registry key instead
-   Ends by listing anything it could not remove, and what to do about it
-   Supports irm/iex one-line command using short URL

## Script Functionality

-   Runs `WRSA.exe -uninstall` if WRSA.exe is present (skipped with `-Force`) and waits for you to answer the prompt
-   Stops and deletes the `WRSVC`, `WRCoreService` and `WRSkyClient` services
-   Kills any running `WRSA` process
-   Removes the Webroot registry keys under `HKLM\SOFTWARE` and the `WRSVC`, `WRkrn`, `WRBoot`, `WRCore`, `WRCoreService` and `wrUrlFlt` service and driver keys under `HKLM\SYSTEM`
-   Removes the `WRSVC` startup entry
-   Removes the Webroot folders under Program Files, ProgramData and the Start Menu
-   Removes any uninstall entry whose name mentions Webroot

## Setup

### Method 1 - One Line Command (Runs Immediately)

The URL [asheroto.com/uninstallwebroot](https://asheroto.com/uninstallwebroot) always redirects to the [latest release](https://github.com/asheroto/Uninstall-Webroot/releases/latest/download/Uninstall-Webroot.ps1) of the script.

If you just need to run the basic script without any parameters, open PowerShell as Administrator and use the following one-line command:

#### Option A: asheroto.com short URL

```powershell
irm asheroto.com/uninstallwebroot | iex
```

Due to the nature of how PowerShell works, you won't be able to use any parameters like `-Force` with this command line. If you need to use a one-line command with parameters, you can use the following:

```powershell
&([ScriptBlock]::Create((irm asheroto.com/uninstallwebroot))) -Force
```

#### Option B: direct release URL

Alternatively, you can of course use the latest release URL directly:

```powershell
irm https://github.com/asheroto/Uninstall-Webroot/releases/latest/download/Uninstall-Webroot.ps1 | iex
```

### Method 2 - Download Locally and Run

As a more conventional approach, download the latest [Uninstall-Webroot.ps1](https://github.com/asheroto/Uninstall-Webroot/releases/latest/download/Uninstall-Webroot.ps1) from [Releases](https://github.com/asheroto/Uninstall-Webroot/releases), then run the script from PowerShell as Administrator as follows:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Uninstall-Webroot.ps1
```

## Parameters

**No parameters are required to run the script.**

| Parameter | Description                                                                                                       |
| --------- | ----------------------------------------------------------------------------------------------------------------- |
| `-Force`  | Skip the Webroot uninstaller and go straight to manual cleanup. Use it when the uninstaller is broken or hangs.   |

### Example Parameters Usage

```powershell
.\Uninstall-Webroot.ps1 -Force
```

```powershell
&([ScriptBlock]::Create((irm asheroto.com/uninstallwebroot))) -Force
```

## Reading the Result

The last lines of output are the result:

| Output                                                                 | Meaning                                                                                                   |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `Nothing left - Webroot has been removed`                              | Done.                                                                                                     |
| `Still present - make sure the uninstall prompt was answered Yes ...`  | The uninstaller ran but did not finish. Run again, or run with `-Force`.                                  |
| `Still present - the uninstaller has already been removed ...`         | Webroot drivers are still loaded. Reboot and run again.                                                   |
| `Still present - reboot to unload the drivers ...`                     | Same, after a `-Force` run. Reboot and run again.                                                         |

The leftover items are listed below the `Still present` line.

## Troubleshooting

-   `Service: WRSkyClient` (or another service) still listed after `sc.exe delete failed (5)`: the script has deleted the service registry key, but Windows keeps the service listed until the next reboot. Reboot and run the script once more.
-   Still present after a reboot: boot into Safe Mode, so the Webroot drivers do not load, and run the script again.

## Notes

-   Run with the one-line command, the script does not check for admin rights up front. A non-admin session fails to remove anything and lists it all as still present.
-   In PowerShell, `sc` is an alias for `Set-Content`. To delete a service by hand, type `sc.exe delete <name>`, not `sc delete <name>`.
