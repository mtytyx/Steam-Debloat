param (
    [string]$Mode = "Normal"
)

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

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

function Main {
    Set-ConsoleProperties
    Kill-SteamProcesses
    Download-Files
    Start-Steam
    Wait-For-SteamClosure
    Move-ConfigFile
    if (Prompt-MoveToDesktop) {
        Move-SteamBatToDesktop
    }
    Remove-TempFiles
    Finish
}

function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-Host "[INFO] Starting $title in $Mode mode" -ForegroundColor $color
}

function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

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

function Start-Steam {
    Write-Host "[INFO] Starting Steam for updates..." -ForegroundColor $color
    Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    Start-Sleep -Seconds 5
}

function Wait-For-SteamClosure {
    Write-Host "[INFO] Waiting for Steam to close..." -ForegroundColor $color
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
    }
}

function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
    } else {
        Write-Host "[ERROR] File $tempPath\$fileSteamCfg not found" -ForegroundColor Red
        Handle-Error "File $tempPath\$fileSteamCfg not found."
    }
}

function Move-SteamBatToDesktop {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Move-Item -Path "$tempPath\$fileSteamBat" -Destination $desktopPath -Force
        Write-Host "[INFO] Moved $fileSteamBat to desktop" -ForegroundColor $color
    }
}

function Remove-TempFiles {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Remove-Item -Path "$tempPath\$fileSteamBat" -Force
        Write-Host "[INFO] Removed $fileSteamBat from TEMP" -ForegroundColor $color
    }
}

function Prompt-MoveToDesktop {
    $response = Read-Host "Do you want to move $fileSteamBat to the desktop? (y/n)"
    return $response -eq "y" -or $response -eq "Y"
}

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

function Finish {
    Write-Host "[SUCCESS] Steam configured and updated." -ForegroundColor $color
}

Main
