param (
    [string]$Mode = "Normal"
)

# the comments are made to help you understand the code

# General Info
$title = "Steam"
$github = "Github.com/mtytyx"
$version = "v2.5"
$color = "Green"
$errorPage = "https://github.com/mtytyx/Steam-Debloat/issues"

$urls = @{
    "Normal" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat" }
    "Lite" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat" }
    "TEST" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat" }
    "TEST-Lite" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat" }
    "TEST-Version" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat" }
}

$steamCfgUrl = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"

$fileSteamBat = if ($Mode -eq "Lite") { "Steam-Lite.bat" } elseif ($Mode -eq "TEST") { "Steam-TEST.bat" } elseif ($Mode -eq "TEST-Lite") { "Steam-Lite-TEST.bat" } elseif ($Mode -eq "TEST-Version") { "Steam-Lite-TEST.bat" } else { "Steam.bat" }
$fileSteamCfg = "steam.cfg"
$tempPath = $env:TEMP
$steamPath = "C:\Program Files (x86)\Steam\steam.exe"
$desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), $fileSteamBat)
$verificationFilePath = "C:\Program Files (x86)\Steam\verification.txt"

$urlSteamBat = $urls[$Mode]["SteamBat"]
$urlSteamCfg = $steamCfgUrl

function Write-WithEffect {
    param (
        [string]$Text,
        [ConsoleColor]$ForegroundColor = $null,
        [int]$Delay = 50
    )

    if ($ForegroundColor) {
        $oldColor = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    foreach ($char in $Text.ToCharArray()) {
        Write-Host -NoNewline $char
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""  # Add a new line

    if ($ForegroundColor) {
        $host.UI.RawUI.ForegroundColor = $oldColor
    }
}

function Main {
    Set-ConsoleProperties
    try {
        Kill-SteamProcesses
        Download-Files

        if ($Mode -eq "TEST-Version") {
            Start-Steam
        } else {
            Verify-Update
            if (-not $global:skipStartSteam) {
                Write-WithEffect "[INFO] Starting Steam for updates..." -ForegroundColor $color
                Start-Steam
                Write-WithEffect "[INFO] Waiting for Steam to close..." -ForegroundColor $color
                Wait-For-SteamClosure
            }
        }
        Move-ConfigFile

        if ($Mode -in @("TEST", "TEST-Lite", "TEST-Version") -or (Prompt-MoveToDesktop)) {
            Move-SteamBatToDesktop
        }
        Remove-TempFiles
        Finish
    } catch {
        Handle-Error "An unexpected error occurred during execution."
    }
}

function Set-ConsoleProperties {
    $host.UI.RawUI.WindowTitle = "$title - $github"
    Write-WithEffect "[INFO] Starting $title Optimization in $Mode mode $version" -ForegroundColor $color
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
    if ($Mode -eq "TEST-Version") {
        $version = Read-Host "Version?"
        $url = "http://web.archive.org/web/$versionif_/media.steampowered.com/client"
        $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $url -exitsteam"
    } else {
        $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
    }
    Start-Process -FilePath $steamPath -ArgumentList $arguments
    Start-Sleep -Seconds 5
}

function Wait-For-SteamClosure {
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
    }
}

function Move-ConfigFile {
    if (Test-Path "$tempPath\$fileSteamCfg") {
        Move-Item -Path "$tempPath\$fileSteamCfg" -Destination "C:\Program Files (x86)\Steam\steam.cfg" -Force
        Write-WithEffect "[INFO] Moved $fileSteamCfg to Steam directory" -ForegroundColor $color
    } else {
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

function Prompt-MoveToDesktop {
    $response = Read-Host "Do you want to move $fileSteamBat to the desktop? (y/n)"
    return $response -eq "y" -or $response -eq "Y"
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
