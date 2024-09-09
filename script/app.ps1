param (
    [string]$Mode = "Normal",
)

# Title and GitHub information
$title = "Steam Debloat"
$github = "Github.com/mtytyx"
$color = "Green"
$errorPage = "https://github.com/mtytyx/Steam-Debloat/issues"

# URL mappings based on mode
$urls = @{
    "Normal" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
    "Lite" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
    "TEST" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
}

# Determine file names based on mode
$fileSteamBat = if ($Mode -eq "Lite") { "Steam-Lite.bat" } elseif ($Mode -eq "TEST") { "Steam-TEST.bat" } else { "Steam.bat" }
$fileSteamCfg = "steam.cfg"
$tempPath = $env:TEMP
$steamPath = "C:\Program Files (x86)\Steam\steam.exe"
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), $fileSteamBat)
$verificationFilePath = "C:\Program Files (x86)\Steam\verification.txt"

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

# Function to write messages to the console with optional color and delay
function Write-WithEffect {
    param (
        [string]$Text,
        [ConsoleColor]$ForegroundColor = $null,
        [int]$Delay = 10  # Reduce delay for faster feedback
    )

    if ($ForegroundColor) {
        $oldColor = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    Write-Host $Text

    if ($ForegroundColor) {
        $host.UI.RawUI.ForegroundColor = $oldColor
    }
}

# Main function to coordinate all steps
function Main {
    Set-ConsoleProperties
    Kill-SteamProcesses
    Download-Files
    Verify-Update
    Start-Steam
    Wait-For-SteamClosure
    Move-ConfigFile
    Move-SteamBatToDesktop  # Directly move to desktop without asking
    Remove-TempFiles
    Finish
    Start-Process $desktopPath  # Execute steam.bat from desktop at the end
}

# Set console properties like title and display initial message
function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-WithEffect "[INFO] Starting $title in $Mode mode" -ForegroundColor $color
}

# Terminate any running Steam processes
function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

# Download necessary files from URLs
function Download-Files {
    Write-WithEffect "[INFO] Downloading files..." -ForegroundColor $color
    try {
        $batFile = "$tempPath\$fileSteamBat"
        $cfgFile = "$tempPath\$fileSteamCfg"
        
        Invoke-WebRequest -Uri $urlSteamBat -OutFile $batFile
        Invoke-WebRequest -Uri $urlSteamCfg -OutFile $cfgFile
    } catch {
        Handle-Error "Failed to download files."
    }
}

# Verify if the update should proceed based on the presence of a verification file
function Verify-Update {
    if (-not (Test-Path $verificationFilePath)) {
        Write-WithEffect "[INFO] Verification file not found..." -ForegroundColor $color
        $verificationContent = "This file is used as a verification to determine whether to proceed with Steam's downgrade or not."
        Set-Content -Path $verificationFilePath -Value $verificationContent
    } else {
        Write-WithEffect "[INFO] Verification file found..." -ForegroundColor $color
        $global:skipStartSteam = $true
    }
}

# Start Steam with update parameters
function Start-Steam {
    Write-WithEffect "[INFO] Starting Steam for updates..." -ForegroundColor $color
    Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    Start-Sleep -Seconds 3  # Reduce sleep time for faster execution
}

# Wait for Steam to close before proceeding
function Wait-For-SteamClosure {
    Write-WithEffect "[INFO] Waiting for Steam to close..." -ForegroundColor $color
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2  # Faster loop for checking process closure
    }
}

# Move the configuration file to the Steam directory
function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
        Write-WithEffect "[INFO] Moved $fileSteamCfg to Steam directory" -ForegroundColor $color
    } else {
        Write-WithEffect "[ERROR] File $tempPath\$fileSteamCfg not found" -ForegroundColor Red
        Handle-Error "File $tempPath\$fileSteamCfg not found."
    }
}

# Move the Steam batch file to the desktop
function Move-SteamBatToDesktop {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Move-Item -Path "$tempPath\$fileSteamBat" -Destination $desktopPath -Force
        Write-WithEffect "[INFO] Moved $fileSteamBat to desktop" -ForegroundColor $color
    }
}

# Remove temporary files after processing
function Remove-TempFiles {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Remove-Item -Path "$tempPath\$fileSteamBat" -Force
        Write-WithEffect "[INFO] Removed $fileSteamBat from TEMP" -ForegroundColor $color
    }
}

# Handle errors by logging the message and redirecting to the issue page
function Handle-Error {
    param (
        [string]$message
    )
    Write-WithEffect "[ERROR] $message" -ForegroundColor Red
    Write-WithEffect "Please report the issue at $errorPage" -ForegroundColor Red
    Write-WithEffect "Press Enter to open the issue page..."
    Read-Host
    Start-Process $errorPage
    exit 1
}

# Final message indicating successful completion
function Finish {
    Write-WithEffect "[SUCCESS] Steam configured and updated." -ForegroundColor $color
}

# Start the script
Main
