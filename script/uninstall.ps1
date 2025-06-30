
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

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -NoNewline -ForegroundColor Yellow
    Write-Host $Message
}

$host.UI.RawUI.BackgroundColor = "Black"

$steamPath = "${env:ProgramFiles(x86)}\Steam"
$steamPathV2 = "${env:ProgramFiles(x86)}\Steamv2"
$desktopBatPath = "$env:USERPROFILE\Desktop\steam.bat"
$startupBatPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\steam.bat"
$backupPath = "$env:TEMP\SteamBackup"
$backupPathV2 = "$env:TEMP\SteamBackupV2"
$steamInstaller = "$env:TEMP\SteamSetup.exe"

$hasSteam = Test-Path $steamPath
$hasSteamV2 = Test-Path $steamPathV2
$isExperimentalMode = $hasSteam -and $hasSteamV2

Write-Host @"
 ______     ______   ______     ______     __    __           
/\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ "-./  \          
\ \___  \  \/_/\ \/ \ \  __\   \ \  __ \  \ \ \-./\ \         
 \/\_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_\ \ \_\        
  \/_____/     \/_/   \/_____/   \/_/\/_/   \/_/  \/_/        
                                                              
           __  __     __   __     __     __   __     ______   ______     __         __        
          /\ \/\ \   /\ "-.\ \   /\ \   /\ "-.\ \   /\  ___\ /\__  _\   /\ \       /\ \       
          \ \ \_\ \  \ \ \-.  \  \ \ \  \ \ \-.  \  \ \___  \\/_/\ \/   \ \ \____  \ \ \____  
           \ \_____\  \ \_\\"\_\  \ \_\  \ \_\\"\_\  \/\_____\  \ \_\    \ \_____\  \ \_____\ 
            \/_____/   \/_/ \/_/   \/_/   \/_/ \/_/   \/_____/   \/_/     \/_____/   \/_____/ 
                                                                                              
"@ -ForegroundColor Red

Write-Info "Steam Downgrade Uninstaller"
Write-Host ""

if ($isExperimentalMode) {
    Write-Warning "Experimental mode detected - Both Steam versions found:"
    Write-Host "  - Steam 2025: $steamPath" -ForegroundColor White
    Write-Host "  - Steam 2022: $steamPathV2" -ForegroundColor White
} elseif ($hasSteam) {
    Write-Info "Standard Steam installation found: $steamPath"
} elseif ($hasSteamV2) {
    Write-Info "Steam v2 installation found: $steamPathV2"
} else {
    Write-ErrorMessage "No Steam installations found!"
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
$confirmation = Read-Host "Do you want to proceed with uninstalling Steam Downgrade? (Y/N)"
if ($confirmation.ToUpper() -ne 'Y') {
    Write-Info "Uninstall cancelled by user."
    exit
}

function Test-SteamRunning {
    $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    return $null -ne $steamProcess
}

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

function Backup-SteamData {
    param(
        [string]$SteamDir,
        [string]$BackupDir,
        [string]$Version
    )
    
    Write-Info "Creating backup for Steam $Version..."
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory | Out-Null
        Write-Success "Backup directory created at: $BackupDir"
    }

    $filesToBackup = @(
        @{Path = "steamapps"; Type = "Directory"},
        @{Path = "config"; Type = "Directory"}
    )
    
    foreach ($item in $filesToBackup) {
        $sourcePath = Join-Path $SteamDir $item.Path
        $destPath = Join-Path $BackupDir $item.Path

        if (Test-Path $sourcePath) {
            Write-Info "Moving $($item.Path) to backup..."
            $parentPath = Split-Path $destPath -Parent
            if (-not (Test-Path $parentPath)) {
                New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
            }
            Move-Item -Path $sourcePath -Destination $destPath -Force
            Write-Success "Successfully moved $($item.Path) for Steam $Version"
        } else {
            Write-Warning "$($item.Path) not found in Steam $Version installation"
        }
    }
}

function Restore-SteamData {
    param(
        [string]$SteamDir,
        [string]$BackupDir,
        [string]$Version
    )
    
    if (Test-Path $BackupDir) {
        Write-Info "Restoring backup files for Steam $Version..."
        
        $filesToRestore = @(
            @{Path = "steamapps"; Type = "Directory"},
            @{Path = "config"; Type = "Directory"}
        )
        
        foreach ($item in $filesToRestore) {
            $sourcePath = Join-Path $BackupDir $item.Path
            $destPath = Join-Path $SteamDir $item.Path

            if (Test-Path $sourcePath) {
                $parentPath = Split-Path $destPath -Parent
                if (-not (Test-Path $parentPath)) {
                    New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
                }
                
                Write-Info "Restoring $($item.Path) for Steam $Version..."
                Move-Item -Path $sourcePath -Destination $destPath -Force
                Write-Success "Successfully restored $($item.Path) for Steam $Version"
            }
        }
        
        Remove-Item -Path $BackupDir -Recurse -Force
        Write-Success "Backup for Steam $Version removed successfully"
    }
}


Write-Info "Removing desktop and startup shortcuts..."
if (Test-Path $desktopBatPath) {
    Remove-Item -Path $desktopBatPath -Force
    Write-Success "Removed desktop steam.bat"
}
if (Test-Path $startupBatPath) {
    Remove-Item -Path $startupBatPath -Force
    Write-Success "Removed startup steam.bat"
}


if (Test-SteamRunning) {
    Write-Info "Closing Steam processes..."
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Success "Steam processes closed"
}

if ($isExperimentalMode) {
    Write-Info "Processing experimental dual installation..."
    
    if ($hasSteam) {
        Backup-SteamData -SteamDir $steamPath -BackupDir $backupPath -Version "2025"
        Write-Info "Removing Steam 2025 installation..."
        Remove-Item -Path $steamPath -Recurse -Force
        Write-Success "Steam 2025 installation removed"
    }
    
    if ($hasSteamV2) {
        Backup-SteamData -SteamDir $steamPathV2 -BackupDir $backupPathV2 -Version "2022"
        Write-Info "Removing Steam 2022 installation..."
        Remove-Item -Path $steamPathV2 -Recurse -Force
        Write-Success "Steam 2022 installation removed"
    }
    
} else {
    $targetPath = if ($hasSteam) { $steamPath } else { $steamPathV2 }
    $targetBackup = if ($hasSteam) { $backupPath } else { $backupPathV2 }
    $version = if ($hasSteam) { "Standard" } else { "V2" }
    
    Backup-SteamData -SteamDir $targetPath -BackupDir $targetBackup -Version $version
    Write-Info "Removing Steam installation..."
    Remove-Item -Path $targetPath -Recurse -Force
    Write-Success "Steam installation removed"
}

Write-Info "Downloading Steam installer..."
try {
    Invoke-WebRequest -Uri "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" -OutFile $steamInstaller
    Write-Success "Steam installer downloaded successfully"
} catch {
    Write-ErrorMessage "Error downloading Steam: $_"
    Read-Host "Press Enter to exit"
    exit
}

Write-Info "Installing clean Steam..."
Start-Process -FilePath $steamInstaller -ArgumentList "/S" -Wait

Write-Info "Waiting for installation to complete..."
if (-not (Wait-ForPath -Path $steamPath -TimeoutSeconds 300)) {
    Write-ErrorMessage "Steam installation did not complete in the expected time"
    Read-Host "Press Enter to exit"
    exit
}

if ($isExperimentalMode) {
    Write-Info "For experimental mode, only restoring Steam 2025 data to main installation..."
    Restore-SteamData -SteamDir $steamPath -BackupDir $backupPath -Version "2025"
    
    Write-Host ""
    Write-Warning "Steam 2022 backup still available at: $backupPathV2"
    $choice = Read-Host "Do you want to keep Steam 2022 backup for manual restoration? (Y/N)"
    if ($choice.ToUpper() -ne 'Y') {
        Remove-Item -Path $backupPathV2 -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "Steam 2022 backup removed"
    } else {
        Write-Info "Steam 2022 backup preserved for manual restoration"
    }
} else {
    $targetBackup = if (Test-Path $backupPath) { $backupPath } else { $backupPathV2 }
    $version = if (Test-Path $backupPath) { "Standard" } else { "V2" }
    Restore-SteamData -SteamDir $steamPath -BackupDir $targetBackup -Version $version
}

Remove-Item -Path $steamInstaller -Force -ErrorAction SilentlyContinue

Write-Info "Starting clean Steam..."
Start-Process "$steamPath\steam.exe" -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
Start-Sleep -Seconds 5
Start-Process "$steamPath\steam.exe"

Write-Host ""
Write-Success "Steam Downgrade uninstallation completed successfully!"
Write-Success "Steam has been restored to its original state."
Write-Info "Your games and configurations have been preserved."
Write-Host ""
Read-Host "Press Enter to exit"
