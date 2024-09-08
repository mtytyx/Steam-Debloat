param (
    [string]$Mode = "Normal"
)

# each function has its description (#) in case you want to know what it does
$title = "Steam Optimization"
$github = "Github.com/mtytyx"
$color = "Green"
$errorPage = "https://github.com/mtytyx/Steam-Debloat/issues"

$urls = @{
    "Normal" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
    "Lite" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
}

$fileSteamBat = if ($Mode -eq "Lite") { "Steam-Lite.bat" } else { "Steam.bat" }
$fileSteamCfg = "steam.cfg"
$tempPath = $env:TEMP
$steamPath = "C:\Program Files (x86)\Steam\steam.exe"
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), $fileSteamBat)
$verificationFilePath = "C:\Program Files (x86)\Steam\verification.txt"

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

# Main function to execute all steps
function Main {
    Set-ConsoleProperties
    Kill-SteamProcesses
    Download-Files
    Verify-Update
    if (-not $skipStartSteam) {
        Start-Steam
    }
    Wait-For-SteamClosure
    Move-ConfigFile
    if (Prompt-MoveToDesktop) {
        Move-SteamBatToDesktop
    }
    Remove-TempFiles
    Finish
}

# Set console properties and display the start message
function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-Host "[INFO] Starting $title in $Mode mode" -ForegroundColor $color
}

# Kill any running Steam processes
function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

# Download necessary files
function Download-Files {
    Write-Host "[INFO] Downloading files..." -ForegroundColor $color
    try {
        $batFile = "$tempPath\$fileSteamBat"
        $cfgFile = "$tempPath\$fileSteamCfg"
        
        Invoke-WebRequest -Uri $urlSteamBat -OutFile $batFile
        Invoke-WebRequest -Uri $urlSteamCfg -OutFile $cfgFile
    } catch {
        Handle-Error "Failed to download files."
    }
}

# Verify if the update process should be skipped
function Verify-Update {
    if (-not (Test-Path $verificationFilePath)) {
        Write-Host "[INFO] Verification file not found. Proceeding with update..." -ForegroundColor $color
        $verificationContent = "This file is used as a verification to determine whether to proceed with Steam's downgrade or not."
        Set-Content -Path $verificationFilePath -Value $verificationContent
    } else {
        Write-Host "[INFO] Verification file found. Skipping update process." -ForegroundColor $color
        $global:skipStartSteam = $true
    }
}

# Start Steam for updates if needed
function Start-Steam {
    Write-Host "[INFO] Starting Steam for updates..." -ForegroundColor $color
    Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    Start-Sleep -Seconds 5
}

# Wait for Steam to close before continuing
function Wait-For-SteamClosure {
    Write-Host "[INFO] Waiting for Steam to close..." -ForegroundColor $color
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
    }
}

# Move the configuration file to the Steam directory
function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
    } else {
        Write-Host "[ERROR] File $tempPath\$fileSteamCfg not found" -ForegroundColor Red
        Handle-Error "File $tempPath\$fileSteamCfg not found."
    }
}

# Move the Steam batch file to the desktop if requested
function Move-SteamBatToDesktop {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Move-Item -Path "$tempPath\$fileSteamBat" -Destination $desktopPath -Force
        Write-Host "[INFO] Moved $fileSteamBat to desktop" -ForegroundColor $color
    }
}

# Remove temporary files from the TEMP directory
function Remove-TempFiles {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Remove-Item -Path "$tempPath\$fileSteamBat" -Force
        Write-Host "[INFO] Removed $fileSteamBat from TEMP" -ForegroundColor $color
    }
}

# Prompt the user to move the Steam batch file to the desktop
function Prompt-MoveToDesktop {
    $response = Read-Host "Do you want to move $fileSteamBat to the desktop? (y/n)"
    return $response -eq "y" -or $response -eq "Y"
}

# Handle errors and prompt the user to report the issue
function Handle-Error {
    param (
        [string]$message
    )
    Write-Host "[ERROR] $message" -ForegroundColor Red
    Write-Host "Please report the issue at $errorPage" -ForegroundColor Red
    Write-Host "Press Enter to open the issue page..."
    Read-Host
    Start-Process $errorPage
    exit 1
}

# Finalize the script execution and display success message
function Finish {
    Write-Host "[SUCCESS] Steam configured and updated." -ForegroundColor $color
}

# Start the main function
Main
