# Logging functions
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

$host.UI.RawUI.BackgroundColor = "Black"

$desktopBatPath = "$env:USERPROFILE\Desktop\steam.bat"
if (Test-Path $desktopBatPath) {
    Remove-Item -Path $desktopBatPath -Force
}

# Define paths
$steamPath = "${env:ProgramFiles(x86)}\Steam"
$backupPath = "$env:TEMP\SteamBackup"
$steamInstaller = "$env:TEMP\SteamSetup.exe"

# Function to check if Steam is running
function Test-SteamRunning {
    $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    return $null -ne $steamProcess
}

# Function to wait for path existence
function Wait-ForPath {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 300
    )
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path $Path)) {
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            Write-ErrorMessage "Timeout waiting for: $Path"
            return $false
        }
        Start-Sleep -Seconds 1
    }
    return $true
}

# Close Steam if running
if (Test-SteamRunning) {
    Write-Info "Closing Steam..."
    Stop-Process -Name "steam" -Force
    Start-Sleep -Seconds 2
}

# Create backup directory if it doesn't exist
if (-not (Test-Path $backupPath)) {
    New-Item -Path $backupPath -ItemType Directory | Out-Null
    Write-Success "Backup directory created at: $backupPath"

    # Check and move important files
    $filesToBackup = @(
        @{Path = "steamapps"; Type = "Directory"},
        @{Path = "config"; Type = "Directory"}
    )

    foreach ($item in $filesToBackup) {
        $sourcePath = Join-Path $steamPath $item.Path
        $destPath = Join-Path $backupPath $item.Path

        if (Test-Path $sourcePath) {
            Write-Info "Moving $($item.Path) to backup..."
            # Ensure destination directory exists
            $parentPath = Split-Path $destPath -Parent
            if (-not (Test-Path $parentPath)) {
                New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
            }
            Move-Item -Path $sourcePath -Destination $destPath -Force
            Write-Success "Successfully moved $($item.Path)"
        } else {
            Write-ErrorMessage "$($item.Path) not found in Steam installation"
        }
    }
}

# Delete Steam directory
if (Test-Path $steamPath) {
    Write-Info "Removing current Steam installation..."
    Remove-Item -Path $steamPath -Recurse -Force
    Write-Success "Steam installation removed successfully"
}

# Download Steam installer
Write-Info "Downloading Steam installer..."
try {
    Invoke-WebRequest -Uri "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" -OutFile $steamInstaller
    Write-Success "Steam installer downloaded successfully"
} catch {
    Write-ErrorMessage "Error downloading Steam: $_"
    exit
}

# Install Steam
Write-Info "Installing Steam..."
Start-Process -FilePath $steamInstaller -ArgumentList "/S" -Wait

# Wait for Steam directory to exist
Write-Info "Waiting for installation to complete..."
if (-not (Wait-ForPath -Path $steamPath -TimeoutSeconds 300)) {
    Write-ErrorMessage "Steam installation did not complete in the expected time"
    exit
}

# Restore backup files
if (Test-Path $backupPath) {
    Write-Info "Restoring backup files..."
    
    foreach ($item in $filesToBackup) {
        $sourcePath = Join-Path $backupPath $item.Path
        $destPath = Join-Path $steamPath $item.Path

        if (Test-Path $sourcePath) {
            # Ensure destination directory exists
            $parentPath = Split-Path $destPath -Parent
            if (-not (Test-Path $parentPath)) {
                New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
            }
            
            Write-Info "Restoring $($item.Path)..."
            Move-Item -Path $sourcePath -Destination $destPath -Force
            Write-Success "Successfully restored $($item.Path)"
        }
    }

    # Remove backup directory
    Remove-Item -Path $backupPath -Recurse -Force
    Write-Success "Backup removed successfully"
}

# Start Steam
Write-Info "Starting Steam..."
Start-Process "$steamPath\steam.exe -forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
Start-Process "$steamPath\steam.exe"
