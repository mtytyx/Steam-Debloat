<#
.SYNOPSIS
    Comprehensive Steam Backup, Reinstall, and Update Script
.DESCRIPTION
    Performs a complete Steam installation reset while preserving user data
    - Moves Steam user data and games to temporary location
    - Downloads latest Steam installer
    - Removes existing Steam installation (except backed up data)
    - Reinstalls Steam silently
    - Forces Steam update
    - Restores previous data
    - Verifies and downloads steamui.dll if needed
    - Starts Steam automatically after installation
.NOTES
    Requires Administrator Privileges
    Tested on Windows 10/11
    PowerShell 5.1+ Recommended
#>

# Check if you are running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges. Rebooting with elevated privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

param(
    [string]$SteamPath = "C:\Program Files (x86)\Steam",
    [string]$BackupPath = "$env:TEMP\SteamBackup",
    [string]$SteamInstallerURL = "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe",
    [string]$DownloadPath = "$env:TEMP\SteamInstaller.exe",
    [string]$SteamUiURL = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steamui.dll"
)

# Console Output Functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] " -NoNewline -ForegroundColor Green
    Write-Host $Message
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] " -NoNewline -ForegroundColor Red
    Write-Host $Message
}

# Feature to force delete files and folders
function Remove-ForcefullyWithTimeout {
    param (
        [string]$Path,
        [int]$TimeoutSeconds = 30
    )
    
    $startTime = Get-Date
    $continue = $true
    
    while ($continue -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        try {
            if (Test-Path -Path $Path) {
                # Intenta obtener acceso exclusivo al archivo
                $handle = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
                $handle.Close()
                $handle.Dispose()
                
                # Si llegamos aquí, el archivo no está en uso
                if (Test-Path -Path $Path -PathType Container) {
                    Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                } else {
                    Remove-Item -Path $Path -Force -ErrorAction Stop
                }
                $continue = $false
            } else {
                $continue = $false
            }
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }
    
    if ((Test-Path -Path $Path) -and $continue) {
        Write-ErrorMessage "Could not delete $Path after $TimeoutSeconds seconds"
        return $false
    }
    return $true
}

# Function to download steamui.dll
function Download-SteamUI {
    param(
        [string]$DestinationPath
    )
    try {
        Write-Info "Downloading steamui.dll..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $SteamUiURL -OutFile $DestinationPath -UseBasicParsing

        if (Test-Path $DestinationPath) {
            Write-Success "steamui.dll downloaded successfully"
            return $true
        }
        return $false
    }
    catch {
        Write-ErrorMessage "Failed to download steamui.dll: $_"
        return $false
    }
}

# Main Script Execution
try {
    # Validate Steam Path
    if (!(Test-Path $SteamPath)) {
        Write-Info "Steam installation directory not found. Proceeding with fresh installation."
    }

    # Stop Steam Process and sus procesos relacionados
    $processesToKill = @("steam", "steamwebhelper", "steamservice", "steamerrorreporter")
    foreach ($processName in $processesToKill) {
        Get-Process $processName -ErrorAction SilentlyContinue | ForEach-Object {
            $_ | Stop-Process -Force
            Write-Info "Stopped $processName process"
        }
    }
    
    # Esperar un momento para asegurar que los procesos se detengan
    Start-Sleep -Seconds 2

    # Prepare Backup Directory
    if (Test-Path $BackupPath) {
        Remove-ForcefullyWithTimeout -Path $BackupPath
    }
    New-Item -ItemType Directory -Path $BackupPath | Out-Null
    Write-Info "Created temporary backup directory"

    # Backup Steam Data
    $steamAppsPath = Join-Path $SteamPath "steamapps"
    $userDataPath = Join-Path $SteamPath "userdata"
    $steamUiPath = Join-Path $SteamPath "steamui.dll"

    # Check and backup steamui.dll
    $hasSteamUi = $false
    if (Test-Path $steamUiPath) {
        Write-Info "Found existing steamui.dll"
        Move-Item -Path $steamUiPath -Destination $BackupPath -Force
        $hasSteamUi = $true
        Write-Success "Moved steamui.dll to temporary location"
    }
    else {
        Write-Info "steamui.dll not found in Steam directory"
    }

    # Backup steamapps (games)
    if (Test-Path $steamAppsPath) {
        Move-Item -Path $steamAppsPath -Destination $BackupPath -Force
        Write-Success "Moved steamapps to temporary location"
    }

    # Backup userdata (account data)
    if (Test-Path $userDataPath) {
        Move-Item -Path $userDataPath -Destination $BackupPath -Force
        Write-Success "Moved userdata to temporary location"
    }

    # Create list of items to exclude from deletion
    $excludeItems = @(
        (Join-Path $BackupPath "steamapps"),
        (Join-Path $BackupPath "userdata"),
        (Join-Path $BackupPath "steamui.dll")
    )

    # Remove Steam Directory (except backed up items)
    if (Test-Path $SteamPath) {
        Get-ChildItem -Path $SteamPath -Recurse | 
        Where-Object { $_.FullName -notin $excludeItems } | 
        ForEach-Object {
            Remove-ForcefullyWithTimeout -Path $_.FullName
        }
        Write-Success "Removed existing Steam installation (preserved user data)"
    }

    # Download Steam Installer
    Write-Info "Downloading Steam Installer..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $SteamInstallerURL -OutFile $DownloadPath -UseBasicParsing

        if (Test-Path $DownloadPath) {
            Write-Success "Steam Installer downloaded successfully"
        }
        else {
            throw "Download failed"
        }
    }
    catch {
        Write-ErrorMessage "Failed to download Steam Installer: $_"
        exit 1
    }

    # Perform Silent Installation
    Write-Info "Starting Silent Steam Installation..."
    try {
        Start-Process -FilePath $DownloadPath -ArgumentList "/S" -Wait -PassThru
        Write-Success "Steam installed silently"
        
        # Start Steam after installation
        $steamExePath = "${env:ProgramFiles(x86)}\Steam\steam.exe"
        if (Test-Path $steamExePath) {
            Write-Info "Starting Steam..."
            Start-Process -FilePath $steamExePath
            Write-Success "Steam has been started"
        }
    }
    catch {
        Write-ErrorMessage "Silent installation failed: $_"
        exit 1
    }

    # Verify Steam Installation
    if (Test-Path $steamExePath) {
        Write-Success "Steam installation verified"
    }
    else {
        Write-ErrorMessage "Steam installation path not found"
        exit 1
    }

    # Restore or Download steamui.dll
    $restoredUiPath = Join-Path $SteamPath "steamui.dll"
    if ($hasSteamUi) {
        Move-Item -Path (Join-Path $BackupPath "steamui.dll") -Destination $SteamPath -Force
        Write-Success "Restored original steamui.dll"
    }
    else {
        # Download new steamui.dll
        if (Download-SteamUI -DestinationPath $restoredUiPath) {
            Write-Success "Downloaded and installed new steamui.dll"
        }
        else {
            Write-ErrorMessage "Failed to acquire steamui.dll"
        }
    }

    # Restore steamapps (games)
    if (Test-Path (Join-Path $BackupPath "steamapps")) {
        Move-Item -Path (Join-Path $BackupPath "steamapps") -Destination $SteamPath -Force
        Write-Success "Restored steamapps (games)"
    }

    # Restore userdata (account data)
    if (Test-Path (Join-Path $BackupPath "userdata")) {
        Move-Item -Path (Join-Path $BackupPath "userdata") -Destination $SteamPath -Force
        Write-Success "Restored userdata (account data)"
    }

    # Force Steam Update
    Start-Process -FilePath $steamExePath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
    Write-Info "Initiated forced Steam update"

    # Clean up installer
    try {
        Remove-ForcefullyWithTimeout -Path $DownloadPath
        Write-Info "Removed Steam installer from temporary location"
    }
    catch {
        Write-ErrorMessage "Could not remove installer: $_"
    }

    # Clean Up Backup Directory
    Remove-ForcefullyWithTimeout -Path $BackupPath
    Write-Success "Completed Steam reinstallation process"
}
catch {
    Write-ErrorMessage "An unexpected error occurred: $_"
    exit 1
}
