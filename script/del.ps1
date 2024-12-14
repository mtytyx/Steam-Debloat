<#
.SYNOPSIS
    Comprehensive Steam Backup, Reinstall, and Update Script
.DESCRIPTION
    Performs a complete Steam installation reset with minimal data loss
    - Moves Steam data to temporary location
    - Downloads latest Steam installer
    - Removes existing Steam installation
    - Reinstalls Steam silently
    - Forces Steam update
    - Restores previous data
.NOTES
    Requires Administrator Privileges
    Tested on Windows 10/11
    PowerShell 5.1+ Recommended
#>
param(
    [string]$SteamPath = "C:\Program Files (x86)\Steam",
    [string]$BackupPath = "$env:TEMP\SteamBackup",
    [string]$SteamInstallerURL = "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe",
    [string]$DownloadPath = "$env:TEMP\SteamInstaller.exe"
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

# Main Script Execution
try {
    # Validate Steam Path
    if (!(Test-Path $SteamPath)) {
        Write-Info "Steam installation directory not found. Proceeding with fresh installation."
    }

    # Stop Steam Process
    $steamProcess = Get-Process "steam" -ErrorAction SilentlyContinue
    if ($steamProcess) {
        $steamProcess | Stop-Process -Force
        Write-Info "Stopped Steam process"
    }

    # Prepare Backup Directory
    if (Test-Path $BackupPath) {
        Remove-Item $BackupPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BackupPath | Out-Null
    Write-Info "Created temporary backup directory"

    # Backup Steam Data
    $steamAppsPath = Join-Path $SteamPath "steamapps"
    $steamUiPath = Join-Path $SteamPath "steamui.dll"

    if (Test-Path $steamAppsPath) {
        Move-Item -Path $steamAppsPath -Destination $BackupPath -Force
        Write-Success "Moved steamapps to temporary location"
    }

    if (Test-Path $steamUiPath) {
        Move-Item -Path $steamUiPath -Destination $BackupPath -Force
        Write-Success "Moved steamui.dll to temporary location"
    }

    # Remove Steam Directory
    if (Test-Path $SteamPath) {
        Remove-Item -Path $SteamPath -Recurse -Force
        Write-Success "Removed existing Steam installation"
    }

    # Download Steam Installer
    Write-Info "Downloading Steam Installer..."
    try {
        # Use TLS 1.2 for secure download
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
    }
    catch {
        Write-ErrorMessage "Silent installation failed: $_"
        exit 1
    }

    # Verify Steam Installation
    $steamExePath = "${env:ProgramFiles(x86)}\Steam\steam.exe"
    if (Test-Path $steamExePath) {
        Write-Success "Steam installation verified"
        
        # Force Steam Update
        Start-Process -FilePath $steamExePath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
        Write-Info "Initiated forced Steam update"
    }
    else {
        Write-ErrorMessage "Steam installation path not found"
        exit 1
    }

    # Restore Backed Up Data
    $restoredAppsPath = Join-Path $SteamPath "steamapps"
    $restoredUiPath = Join-Path $SteamPath "steamui.dll"

    if (Test-Path (Join-Path $BackupPath "steamapps")) {
        Move-Item -Path (Join-Path $BackupPath "steamapps") -Destination $SteamPath -Force
        Write-Success "Restored steamapps"
    }

    if (Test-Path (Join-Path $BackupPath "steamui.dll")) {
        Move-Item -Path (Join-Path $BackupPath "steamui.dll") -Destination $SteamPath -Force
        Write-Success "Restored steamui.dll"
    }

    # Clean up installer
    try {
        Remove-Item -Path $DownloadPath -Force
        Write-Info "Removed Steam installer from temporary location"
    }
    catch {
        Write-ErrorMessage "Could not remove installer: $_"
    }

    # Clean Up Backup Directory
    Remove-Item -Path $BackupPath -Recurse -Force
    Write-Success "Completed Steam reinstallation process"
}
catch {
    Write-ErrorMessage "An unexpected error occurred: $_"
    exit 1
}
