<#PSScriptInfo

.VERSION 1.0.1

.GUID c81e25c3-42d9-4e88-9f73-c841292e44ee

.AUTHOR asheroto

.COMPANYNAME asheroto

.TAGS PowerShell Windows Webroot SecureAnywhere OpenText Endpoint Protection uninstall remove

.PROJECTURI https://github.com/asheroto/Uninstall-Webroot

.RELEASENOTES
[Version 1.0.0] - Initial release.
[Version 1.0.1] - With -Force, the leftover message no longer says the uninstaller has already been removed.

#>

<#
.SYNOPSIS
    Remove Webroot SecureAnywhere (OpenText Endpoint Protection) by force.

.DESCRIPTION
    Run interactively from an admin PowerShell on the device. If WRSA.exe is still present it
    runs the Webroot uninstaller first, which shows a confirmation prompt that must be answered
    Yes. It then removes the Webroot services, registry keys, startup entries, folders and
    uninstall entries, and lists anything it could not remove.

    Options:
      -Force   Skip the uninstaller and go straight to manual cleanup.

    Safe to run again. If anything is still present after a run, reboot to unload the
    drivers and run it once more.
#>
#Requires -RunAsAdministrator

param(
    [switch]$Force
)

# Webroot SecureAnywhere registry keys
$RegKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\WRData",
    "HKLM:\SOFTWARE\WOW6432Node\WRCore",
    "HKLM:\SOFTWARE\WOW6432Node\WRMIDData",
    "HKLM:\SOFTWARE\WOW6432Node\webroot",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WRData",
    "HKLM:\SOFTWARE\WRMIDData",
    "HKLM:\SOFTWARE\WRCore",
    "HKLM:\SOFTWARE\webroot",
    "HKLM:\SYSTEM\ControlSet001\services\WRSVC",
    "HKLM:\SYSTEM\ControlSet001\services\WRkrn",
    "HKLM:\SYSTEM\ControlSet001\services\WRBoot",
    "HKLM:\SYSTEM\ControlSet001\services\WRCore",
    "HKLM:\SYSTEM\ControlSet001\services\WRCoreService",
    "HKLM:\SYSTEM\ControlSet001\services\wrUrlFlt",
    "HKLM:\SYSTEM\ControlSet002\services\WRSVC",
    "HKLM:\SYSTEM\ControlSet002\services\WRkrn",
    "HKLM:\SYSTEM\ControlSet002\services\WRBoot",
    "HKLM:\SYSTEM\ControlSet002\services\WRCore",
    "HKLM:\SYSTEM\ControlSet002\services\WRCoreService",
    "HKLM:\SYSTEM\ControlSet002\services\wrUrlFlt",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRSVC",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRkrn",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRBoot",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRCore",
    "HKLM:\SYSTEM\CurrentControlSet\services\WRCoreService",
    "HKLM:\SYSTEM\CurrentControlSet\services\wrUrlFlt"
)

# Startup locations
$RegStartupPaths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

# Webroot folders
$Folders = @(
    "$Env:ProgramData\WRData",
    "$Env:ProgramData\WRCore",
    "$Env:ProgramFiles\Webroot",
    "${Env:ProgramFiles(x86)}\Webroot",
    "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\Webroot SecureAnywhere",
    "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\OpenText*Endpoint Protection",
    "$Env:ProgramFiles\Common Files\Webroot"
)

# Known service names
$Services = @("WRSVC", "WRCoreService", "WRSkyClient")

# Attempt uninstall if WRSA.exe found
$WrsaPaths = @(
    "${Env:ProgramFiles(x86)}\Webroot\WRSA.exe",
    "${Env:ProgramFiles}\Webroot\WRSA.exe"
)

$UninstallerRan = $false
foreach ($Wrsa in $WrsaPaths) {
    if (-not $Force -and (Test-Path $Wrsa)) {
        $UninstallerRan = $true
        Write-Output "Uninstalling via $Wrsa"
        try {
            Start-Process -FilePath $Wrsa -ArgumentList "-uninstall" -ErrorAction Stop
            # The launched WRSA.exe hands off to the already running WRSA instance and exits, and that
            # instance does not exit when the prompt is answered, so there is no process to wait on
            Write-Host "ACTION REQUIRED: click Yes on the Webroot uninstall prompt. If the uninstaller is broken, press Ctrl+C and rerun with -Force." -ForegroundColor Yellow
            Read-Host "Press Enter once the Webroot uninstall has finished" | Out-Null
        }
        catch {
            Write-Warning "Uninstaller failed to run ($($_.Exception.Message)) - continuing with manual cleanup"
        }
    }
}

# Stop and delete services
foreach ($ServiceName in $Services) {
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Output "Stopping and removing service: $ServiceName"
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $ServiceName | Out-Null
        # SCM can refuse with Access denied even when elevated - removing the service key directly works, and the service is gone after a reboot
        if ($LASTEXITCODE -ne 0) {
            Write-Output "sc.exe delete failed ($LASTEXITCODE) - removing service registry key instead"
            Remove-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Kill WRSA.exe process
Write-Output "Killing WRSA process (if running)"
Stop-Process -Name "WRSA" -Force -ErrorAction SilentlyContinue

# Remove registry keys
foreach ($RegKey in $RegKeys) {
    if (Test-Path $RegKey) {
        Write-Output "Removing registry key: $RegKey"
        Remove-Item -Path $RegKey -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Remove startup entries
foreach ($RegStartupPath in $RegStartupPaths) {
    $StartupEntry = Get-ItemProperty -Path $RegStartupPath -ErrorAction SilentlyContinue
    if ($null -ne $StartupEntry -and $StartupEntry.PSObject.Properties.Name -contains "WRSVC") {
        Write-Output "Removing WRSVC from startup: $RegStartupPath"
        Remove-ItemProperty -Path $RegStartupPath -Name "WRSVC" -ErrorAction SilentlyContinue
    }
}

# Remove folders
foreach ($Folder in $Folders) {
    if (Test-Path $Folder) {
        Write-Output "Removing folder: $Folder"
        Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove any uninstall entries that mention Webroot
$UninstallRootPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($RootPath in $UninstallRootPaths) {
    Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue | ForEach-Object {
        $Props = Get-ItemProperty -Path $_.PsPath -ErrorAction SilentlyContinue
        if ($null -ne $Props.DisplayName -and $Props.DisplayName -like "*Webroot*") {
            Write-Output "Removing detected uninstall key: $($_.PsPath) [$($Props.DisplayName)]"
            Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Report anything still present
$Leftovers = @($RegKeys + $Folders | Where-Object { Test-Path $_ })
$Leftovers += @(Get-Service -Name $Services -ErrorAction SilentlyContinue | ForEach-Object { "Service: $($_.Name)" })
if ($Leftovers) {
    if ($UninstallerRan) {
        Write-Output "Still present - make sure the uninstall prompt was answered Yes and run the script again, or run it with -Force to skip the uninstaller:"
    }
    elseif ($Force) {
        Write-Output "Still present - reboot to unload the drivers and run the script again:"
    }
    else {
        Write-Output "Still present - the uninstaller has already been removed, so reboot to unload the drivers and run the script again:"
    }
    $Leftovers
}
else {
    Write-Output "Nothing left - Webroot has been removed"
}
