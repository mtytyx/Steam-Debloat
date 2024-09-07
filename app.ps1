param (
    [string]$Mode = "Normal"
)

# Variables
$title = "Steam Downgrade"
$githubRepo = "GitHub.com/mtytyx"
$color = "Green"

$urls = @{
    "Normal" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/Steam.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/steam.cfg"
    }
    "Lite" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/Steam-Lite.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/steam.cfg"
    }
}

$fileSteamBat = "Steam.bat"
$fileSteamCfg = "steam.cfg"
$tempPath = $env:TEMP
$steamPath = "C:\Program Files (x86)\Steam\steam.exe"

if (-not $urls.ContainsKey($Mode)) {
    Write-Host "[ERROR] Invalid mode specified. Use 'Normal' or 'Lite'."
    Exit 1
}

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

function Main {
    Set-ConsoleProperties
    Kill-SteamProcesses
    Download-Files
    Start-Steam
    Check-SteamClosed
    Move-ConfigFile
    Main-Menu
}

function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $githubRepo"
    Write-Host -ForegroundColor $color
}

function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

function Download-Files {
    Write-Host "[INFO] Downloading files, please wait..."
    Invoke-WebRequest -Uri $urlSteamBat -OutFile "$tempPath\$fileSteamBat"
    Invoke-WebRequest -Uri $urlSteamCfg -OutFile "$tempPath\$fileSteamCfg"
    Write-Host "[SUCCESS] Files downloaded successfully."
    Start-Sleep -Seconds 2
}

function Start-Steam {
    Write-Host "[INFO] Starting Steam for update..."
    Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    Start-Sleep -Seconds 5
}

function Check-SteamClosed {
    Write-Host "[INFO] Waiting for Steam to close completely..."
    while (Get-Process -Name "steam", "steamservice", "steamwebhelper" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 10
    }
}

function Move-ConfigFile {
    Write-Host "[INFO] Moving configuration file..."
    Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
    Write-Host "[SUCCESS] Configuration file moved successfully."
}

function Main-Menu {
    Clear-Host
    Write-Host "[INFO] Process completed. Do you want to move the .bat file to the desktop?"
    Write-Host "1) Yes"
    Write-Host "2) No"
    $option = Read-Host "Select an option (1 or 2)"
    if ($option -eq "1") {
        Move-ToDesktop
    } elseif ($option -eq "2") {
        Exit
    }
}

function Move-ToDesktop {
    Write-Host "[INFO] Moving .bat file to the desktop..."
    Move-Item -Path "$tempPath\$fileSteamBat" -Destination "C:\Users\$env:USERNAME\Desktop" -Force
    Start-Sleep -Seconds 3
    Exit
}

Main
