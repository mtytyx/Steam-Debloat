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

# Define paths
$steamPath = "${env:ProgramFiles(x86)}\Steam"
$backupPath = "$env:TEMP\SteamBackup"
$steamInstaller = "$env:TEMP\SteamSetup.exe"

# Check maintenance status
function Check-Maintenance {
    try {
        Write-Info "Checking maintenance status..."
        $response = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/refs/heads/main/maintenancedel.json"
        if ($response.maintenance -eq $true) {
            Clear-Host
            Write-Host @"

 ______     ______   ______     ______     __    __                                                           
/\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ "-./  \                                                          
\ \___  \  \/_/\ \/ \ \  __\   \ \  __ \  \ \ \-./\ \                                                         
 \/\_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_\ \ \_\                                                        
  \/_____/     \/_/   \/_____/   \/_/\/_/   \/_/  \/_/                                                        
                                                                                                              
                __  __     __   __     __     __   __     ______     ______   ______     __         __        
               /\ \/\ \   /\ "-.\ \   /\ \   /\ "-.\ \   /\  ___\   /\__  _\ /\  __ \   /\ \       /\ \       
               \ \ \_\ \  \ \ \-.  \  \ \ \  \ \ \-.  \  \ \___  \  \/_/\ \/ \ \  __ \  \ \ \____  \ \ \____  
                \ \_____\  \ \_\\"\_\  \ \_\  \ \_\\"\_\  \/\_____\    \ \_\  \ \_\ \_\  \ \_____\  \ \_____\ 
                 \/_____/   \/_/ \/_/   \/_/   \/_/ \/_/   \/_____/     \/_/   \/_/\/_/   \/_____/   \/_____/ 
                                                                                                              
                     MAINTENANCE IN PROGRESS
"@ -ForegroundColor Red
            Write-Host "`nReason for maintenance:" -ForegroundColor Cyan
            Write-Host "$($response.message)" -ForegroundColor Yellow
            Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
            Read-Host
            exit
        }
    }
    catch {
        Write-Warning "Unable to check maintenance status. Continuing..."
        return
    }
}

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

# Function to download steamui.dll
function Get-SteamUIDll {
    param([string]$destinationPath)
    try {
        Write-Info "Downloading steamui.dll..."
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steamui.dll" -OutFile $destinationPath
        Write-Success "steamui.dll downloaded successfully"
        return $true
    } catch {
        Write-ErrorMessage "Failed to download steamui.dll: $_"
        return $false
    }
}

# Check maintenance status
Check-Maintenance

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
        @{Path = "config"; Type = "Directory"},
        @{Path = "steamui.dll"; Type = "File"}
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
            if ($item.Path -eq "steamui.dll") {
                Get-SteamUIDll -destinationPath $destPath
            }
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
Start-Process "$steamPath\steam.exe"
