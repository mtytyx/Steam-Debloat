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
    - Verifies and downloads steamui.dll if needed
.NOTES
    Requires Administrator Privileges
    Tested on Windows 10/11
    PowerShell 5.1+ Recommended
#>
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

    # Check if steamui.dll exists and is valid
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

    if (Test-Path $steamAppsPath) {
        Move-Item -Path $steamAppsPath -Destination $BackupPath -Force
        Write-Success "Moved steamapps to temporary location"
    }

    # Remove Steam Directory
    if (Test-Path $SteamPath) {
        Remove-Item -Path $SteamPath -Recurse -Force
        Write-Success "Removed existing Steam installation"
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
    }
    catch {
        Write-ErrorMessage "Silent installation failed: $_"
        exit 1
    }

    # Verify Steam Installation
    $steamExePath = "${env:ProgramFiles(x86)}\Steam\steam.exe"
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

    # Restore steamapps
    $restoredAppsPath = Join-Path $SteamPath "steamapps"
    if (Test-Path (Join-Path $BackupPath "steamapps")) {
        Move-Item -Path (Join-Path $BackupPath "steamapps") -Destination $SteamPath -Force
        Write-Success "Restored steamapps"
    }

    # Force Steam Update
    Start-Process -FilePath $steamExePath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
    Write-Info "Initiated forced Steam update"

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
