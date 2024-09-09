:param (
    [string]$Mode = "Normal",
    [string]$Date = ""  # Variable para el modo TEST-VERSION
)

$title = "Steam Debloat"
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
    "TEST" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
    "TEST-VERSION" = @{
        "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
}

$fileSteamBat = if ($Mode -eq "Lite") { "Steam-Lite.bat" } elseif ($Mode -eq "TEST-VERSION") { "Steam-test-version.bat" } elseif ($Mode -eq "TEST") { "Steam-TEST.bat" } else { "Steam.bat" }
$fileSteamCfg = "steam.cfg"
$tempPath = $env:TEMP
$steamPath = "C:\Program Files (x86)\Steam\steam.exe"
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), $fileSteamBat)
$verificationFilePath = "C:\Program Files (x86)\Steam\verification.txt"

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $urls[$Mode]["SteamCfg"]

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
    Move-SteamBatToDesktop  # Directly move to desktop without asking
    Remove-TempFiles
    Finish
    Start-Process $desktopPath  # Execute steam.bat from desktop at the end
}

function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-WithEffect "[INFO] Starting $title in $Mode mode" -ForegroundColor $color
}

function Kill-SteamProcesses {
    Stop-Process -Name "steam" -Force -ErrorAction SilentlyContinue
}

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

function Start-Steam {
    if ($Mode -eq "TEST-VERSION" -and $Date) {
        Write-WithEffect "[INFO] Starting Steam for specific version update..." -ForegroundColor $color
        Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl http://web.archive.org/web/$Date/media.steampowered.com/client/steam_client_win32 -exitsteam"
    } else {
        Write-WithEffect "[INFO] Starting Steam for updates..." -ForegroundColor $color
        Start-Process -FilePath $steamPath -ArgumentList "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    }
    Start-Sleep -Seconds 3  # Reduce sleep time for faster execution
}

function Wait-For-SteamClosure {
    Write-WithEffect "[INFO] Waiting for Steam to close..." -ForegroundColor $color
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2  # Faster loop for checking process closure
    }
}

function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
        Write-WithEffect "[INFO] Moved $fileSteamCfg to Steam directory" -ForegroundColor $color
    } else {
        Write-WithEffect "[ERROR] File $tempPath\$fileSteamCfg not found" -ForegroundColor Red
        Handle-Error "File $tempPath\$fileSteamCfg not found."
    }
}

function Move-SteamBatToDesktop {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Move-Item -Path "$tempPath\$fileSteamBat" -Destination $desktopPath -Force
        Write-WithEffect "[INFO] Moved $fileSteamBat to desktop" -ForegroundColor $color
    }
}

function Remove-TempFiles {
    if (Test-Path "$tempPath\$fileSteamBat") {
        Remove-Item -Path "$tempPath\$fileSteamBat" -Force
        Write-WithEffect "[INFO] Removed $fileSteamBat from TEMP" -ForegroundColor $color
    }
}

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

function Finish {
    Write-WithEffect "[SUCCESS] Steam configured and updated." -ForegroundColor $color
}

Main
