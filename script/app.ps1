param (
    [string]$Mode = "Normal"
)

# Configuration
$config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx"
    Version = @{
        Stable = "v2.8"
        Beta = "v1.1"
    }
    Color = @{
        Info = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
    }
    ErrorPage = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls = @{
        "Normal" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat" }
        "Lite" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat" }
        "TEST" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat" }
        "TEST-Lite" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat" }
        "TEST-Version" = @{ "SteamBat" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat" }
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
}

# File and path variables
$files = @{
    SteamBat = switch ($Mode) {
        "Lite" { "Steam-Lite.bat" }
        "TEST" { "Steam-TEST.bat" }
        "TEST-Lite" { "Steam-Lite-TEST.bat" }
        "TEST-Version" { "Steam-TEST.bat" }
        default { "Steam.bat" }
    }
    SteamCfg = "steam.cfg"
}

$paths = @{
    Temp = $env:TEMP
    Steam = "C:\Program Files (x86)\Steam\steam.exe"
    Desktop = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), $files.SteamBat)
}

# Helper Functions
function Write-ColoredMessage {
    param (
        [string]$Message,
        [string]$ColorName,
        [int]$Delay = 10
    )
    
    $color = $config.Color[$ColorName]
    Write-Host -NoNewline "["
    Write-Host -NoNewline $ColorName.ToUpper() -ForegroundColor $color
    Write-Host -NoNewline "] "
    
    foreach ($char in $Message.ToCharArray()) {
        Write-Host -NoNewline $char
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ""
}

function Invoke-SafeWebRequest {
    param (
        [string]$Uri,
        [string]$OutFile
    )
    
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    }
    catch {
        throw "Failed to download file from $Uri. Error: $_"
    }
}

function Test-AdminPrivileges {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ProcessAsAdmin {
    param (
        [string]$FilePath,
        [string]$ArgumentList
    )
    
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs
}

# Main Functions
function Show-Introduction {
    Clear-Host
    Write-Host "`nWelcome to $($config.Title) - $($config.GitHub)`n"
    Write-Host "This script optimizes and debloats Steam for better performance."
    Write-Host "------------------------------------------------"
    Write-Host "1. Steam Debloat Stable (Version $($config.Version.Stable))"
    Write-Host "2. Steam Debloat Beta (Version $($config.Version.Beta))"
    Write-Host "------------------------------------------------`n"
}

function Get-UserSelection {
    do {
        $choice = Read-Host "Please choose an option (1 or 2)"
        switch ($choice) {
            1 {
                $script:Mode = Read-Host "Choose mode: Normal or Lite"
                if ($script:Mode -notin @("Normal", "Lite")) {
                    Write-ColoredMessage "Invalid choice. Please try again." "Error"
                    continue
                }
            }
            2 {
                $script:Mode = Read-Host "Choose mode: TEST, TEST-Lite, or TEST-Version"
                if ($script:Mode -notin @("TEST", "TEST-Lite", "TEST-Version")) {
                    Write-ColoredMessage "Invalid choice. Please try again." "Error"
                    continue
                }
            }
            default {
                Write-ColoredMessage "Invalid choice. Please try again." "Error"
                continue
            }
        }
        return $true
    } while ($true)
}

function Initialize-Environment {
    $host.UI.RawUI.WindowTitle = "$($config.Title) - $($config.GitHub)"
    $version = if ($Mode -like "TEST*") { $config.Version.Beta } else { $config.Version.Stable }
    Write-ColoredMessage "Starting $($config.Title) Optimization in $Mode mode $version" "Info"
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColoredMessage "Requesting administrator privileges..." "Warning"
        Start-ProcessAsAdmin -FilePath "powershell.exe" -ArgumentList "-File `"$PSCommandPath`" -Mode `"$Mode`""
        exit
    }
}

function Stop-SteamProcesses {
    Write-ColoredMessage "Stopping Steam processes..." "Info"
    Get-Process | Where-Object { $_.Name -like "*steam*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Get-Files {
    Write-ColoredMessage "Downloading required files..." "Info"
    
    $steamBatUrl = $config.Urls[$Mode].SteamBat
    $steamCfgUrl = $config.Urls.SteamCfg
    
    try {
        Invoke-SafeWebRequest -Uri $steamBatUrl -OutFile (Join-Path $paths.Temp $files.SteamBat)
        Write-ColoredMessage "Successfully downloaded $($files.SteamBat)" "Success"
        
        Invoke-SafeWebRequest -Uri $steamCfgUrl -OutFile (Join-Path $paths.Temp $files.SteamCfg)
        Write-ColoredMessage "Successfully downloaded $($files.SteamCfg)" "Success"
    }
    catch {
        throw "Failed to download files. Error: $_"
    }
}

function Invoke-SteamDowngrade {
    if ($Mode -eq "TEST-Version" -or (Read-Host "Do you want to downgrade Steam? (y/n)") -eq 'y') {
        $version = if ($Mode -eq "TEST-Version") { Read-Host "Enter the desired Steam version" } else { "dec2022steam" }
        $url = if ($Mode -eq "TEST-Version") { 
            "http://web.archive.org/web/$($version)if_/media.steampowered.com/client"
        } else {
            "https://archive.org/download/$version"
        }
        
        $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $url -exitsteam"
        Write-ColoredMessage "Starting Steam downgrade process..." "Info"
        Start-Process -FilePath $paths.Steam -ArgumentList $arguments
        
        Write-ColoredMessage "Waiting for Steam to close..." "Info"
        while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
            Start-Sleep -Seconds 5
        }
    }
}

function Move-ConfigFile {
    $source = Join-Path $paths.Temp $files.SteamCfg
    $destination = "C:\Program Files (x86)\Steam\steam.cfg"
    
    if (Test-Path $source) {
        Move-Item -Path $source -Destination $destination -Force
        Write-ColoredMessage "Moved $($files.SteamCfg) to Steam directory" "Success"
    }
    else {
        throw "File $source not found."
    }
}

function Move-SteamBatToDesktop {
    if ($Mode -like "TEST*" -or (Read-Host "Do you want to move $($files.SteamBat) to the desktop? (y/n)") -eq 'y') {
        $source = Join-Path $paths.Temp $files.SteamBat
        if (Test-Path $source) {
            Move-Item -Path $source -Destination $paths.Desktop -Force
            Write-ColoredMessage "Moved $($files.SteamBat) to desktop" "Success"
        }
    }
}

function Remove-TempFiles {
    Get-ChildItem $paths.Temp -Filter "Steam*.bat" | Remove-Item -Force
    Write-ColoredMessage "Removed temporary files" "Success"
}

function Show-Completion {
    Write-ColoredMessage "Steam configured and updated successfully." "Success"
    Write-Host "`nThank you for using $($config.Title)!"
    Write-Host "If you encounter any issues, please report them at: $($config.ErrorPage)"
    Read-Host "`nPress Enter to exit"
}

# Main execution
try {
    Show-Introduction
    if (-not (Get-UserSelection)) { exit }
    
    Initialize-Environment
    Stop-SteamProcesses
    Get-Files
    Invoke-SteamDowngrade
    Move-ConfigFile
    Move-SteamBatToDesktop
    Remove-TempFiles
    Show-Completion
}
catch {
    Write-ColoredMessage "An error occurred: $_" "Error"
    Write-ColoredMessage "Please report this issue at $($config.ErrorPage)" "Error"
    Read-Host "Press Enter to open the issue page..."
    Start-Process $config.ErrorPage
    exit 1
}
