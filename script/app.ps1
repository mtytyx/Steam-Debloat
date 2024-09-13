param (
    [string]$Mode = $null
)

# Configuration
$config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx"
    Version = @{
        Stable = "v2.9"
        Beta = "v1.2"
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
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
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
                $selectedMode = Read-Host "Choose mode: Normal or Lite"
                if ($selectedMode -notin @("Normal", "Lite")) {
                    Write-ColoredMessage "Invalid choice. Please try again." "Error"
                    continue
                }
            }
            2 {
                $selectedMode = Read-Host "Choose mode: TEST, TEST-Lite, or TEST-Version"
                if ($selectedMode -notin @("TEST", "TEST-Lite", "TEST-Version")) {
                    Write-ColoredMessage "Invalid choice. Please try again." "Error"
                    continue
                }
            }
            default {
                Write-ColoredMessage "Invalid choice. Please try again." "Error"
                continue
            }
        }
        return $selectedMode
    } while ($true)
}

function Initialize-Environment {
    param (
        [string]$SelectedMode
    )
    $host.UI.RawUI.WindowTitle = "$($config.Title) - $($config.GitHub)"
    $version = if ($SelectedMode -like "TEST*") { $config.Version.Beta } else { $config.Version.Stable }
    Write-ColoredMessage "Starting $($config.Title) Optimization in $SelectedMode mode $version" "Info"
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColoredMessage "Requesting administrator privileges..." "Warning"
        Start-ProcessAsAdmin -FilePath "powershell.exe" -ArgumentList "-File `"$PSCommandPath`" -Mode `"$SelectedMode`""
        exit
    }
}

function Stop-SteamProcesses {
    Write-ColoredMessage "Stopping Steam processes..." "Info"
    Get-Process | Where-Object { $_.Name -like "*steam*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Get-Files {
    param (
        [string]$SelectedMode
    )
    Write-ColoredMessage "Downloading required files for $SelectedMode mode..." "Info"
    
    $steamBatUrl = $config.Urls[$SelectedMode].SteamBat
    $steamCfgUrl = $config.Urls.SteamCfg
    
    try {
        $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
        Invoke-SafeWebRequest -Uri $steamBatUrl -OutFile $steamBatPath
        Write-ColoredMessage "Successfully downloaded Steam-$SelectedMode.bat" "Success"
        
        $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
        Invoke-SafeWebRequest -Uri $steamCfgUrl -OutFile $steamCfgPath
        Write-ColoredMessage "Successfully downloaded steam.cfg" "Success"
        
        return @{
            SteamBat = $steamBatPath
            SteamCfg = $steamCfgPath
        }
    }
    catch {
        throw "Failed to download files. Error: $_"
    }
}

function Invoke-SteamUpdate {
    param (
        [string]$Url
    )
    
    Write-ColoredMessage "Starting Steam update process..." "Info"
    $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"
    Start-Process -FilePath "C:\Program Files (x86)\Steam\steam.exe" -ArgumentList $arguments
    
    Write-ColoredMessage "Waiting for Steam to close..." "Info"
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 5
    }
}

function Move-ConfigFile {
    param (
        [string]$SourcePath
    )
    $destination = "C:\Program Files (x86)\Steam\steam.cfg"
    
    if (Test-Path $SourcePath) {
        Move-Item -Path $SourcePath -Destination $destination -Force
        Write-ColoredMessage "Moved steam.cfg to Steam directory" "Success"
    }
    else {
        throw "File $SourcePath not found."
    }
}

function Move-SteamBatToDesktop {
    param (
        [string]$SourcePath,
        [string]$SelectedMode
    )
    if ($SelectedMode -like "TEST*" -or (Read-Host "Do you want to move Steam-$SelectedMode.bat to the desktop? (y/n)") -eq 'y') {
        if (Test-Path $SourcePath) {
            $desktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Steam-$SelectedMode.bat")
            Move-Item -Path $SourcePath -Destination $desktopPath -Force
            Write-ColoredMessage "Moved Steam-$SelectedMode.bat to desktop" "Success"
        }
    }
}

function Remove-TempFiles {
    Get-ChildItem $env:TEMP -Filter "Steam*.bat" | Remove-Item -Force
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
    if (-not $Mode) {
        Show-Introduction
        $Mode = Get-UserSelection
    }
    
    Initialize-Environment -SelectedMode $Mode
    Stop-SteamProcesses
    $files = Get-Files -SelectedMode $Mode
    
    if ($Mode -eq "TEST-Version") {
        $version = Read-Host "Enter the desired Steam version"
        $url = "http://web.archive.org/web/$($version)if_/media.steampowered.com/client"
        Invoke-SteamUpdate -Url $url
    } else {
        $downgrade = Read-Host "Do you want to downgrade Steam to December 2022 version? (y/n)"
        if ($downgrade -eq 'y') {
            Invoke-SteamUpdate -Url $config.DefaultDowngradeUrl
        }
    }
    
    Move-ConfigFile -SourcePath $files.SteamCfg
    Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $Mode
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
