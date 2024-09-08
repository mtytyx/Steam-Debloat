param (
    [string]$Mode = "Normal"
)

$title = "Steam Optimization"
$github = "Github.com/mtytyx"
$color = "Green"

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

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

function Main {
    Set-ConsoleProperties
    Kill-SteamProcesses
    Download-Files
    Start-Steam
    Wait-For-SteamClosure
    Move-ConfigFile
    Finish
}

function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-Host "[INFO] Starting $title" -ForegroundColor $color
}

function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

function Download-Files {
    try {
        Invoke-WebRequest -Uri $urlSteamBat -OutFile "$tempPath\$fileSteamBat"
    } catch {
        Write-Host "[ERROR] Failed to download $urlSteamBat" -ForegroundColor Red
        Write-Host "Error details: $_"
        exit 1
    }
    
    try {
        Invoke-WebRequest -Uri $urlSteamCfg -OutFile "$tempPath\$fileSteamCfg"
    } catch {
        Write-Host "[ERROR] Failed to download $urlSteamCfg" -ForegroundColor Red
        Write-Host "Error details: $_"
        exit 1
    }
}

function Start-Steam {
    Write-Host "[INFO] Starting Steam for updates..."
    Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -exitsteam"
    Start-Sleep -Seconds 5
}

function Wait-For-SteamClosure {
    Write-Host "[INFO] Waiting for Steam to close..."
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
    }
}

function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
    } else {
        Write-Host "[ERROR] File $tempPath\$fileSteamCfg not found" -ForegroundColor Red
    }
}

function Finish {
    Write-Host "[SUCCESS] Steam configured and updated."
}

Main
