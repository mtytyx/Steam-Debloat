[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Normal", "Lite", "TEST")]
    [string]$Mode = "Normal",
    [switch]$SkipIntro,
    [switch]$NoInteraction
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Debug Configuration - Set to "on" to enable logging | Set to "off" to disable logging(default)
$Debug = "off"

# Configuration
$script:config = @{
    Title               = "Steam Debloat"
    GitHub              = "Github.com/mtytyx/Steam-Debloat"
    Version             = "v1.0.035"
    Color               = @{Info = "Green"; Success = "Green"; Warning = "Yellow"; Error = "Red"; Debug = "Green" }
    ErrorPage           = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls                = @{
        "Normal"           = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "Lite"             = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "TEST"             = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg"         = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
        "SteamSetup"       = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
        "MaintenanceCheck" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/maintenance.json"
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    SteamInstallDir     = "C:\Program Files (x86)\Steam"
    RetryAttempts       = 3
    RetryDelay          = 5
    LogFile             = Join-Path $env:TEMP "Steam-Debloat.log"
}

# Debug logging function
function Write-DebugLog {
    param (
        [string]$Message,
        [string]$Level = "Info"
    )

    Write-Host "[$Level] $Message" -ForegroundColor $script:config.Color[$Level]

    if ($Debug -eq "on") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        Add-Content -Path $script:config.LogFile -Value $logMessage
    }
}

# Check maintenance status
function Test-MaintenanceStatus {
    try {
        $response = Invoke-RestMethod -Uri $script:config.Urls.MaintenanceCheck -UseBasicParsing
        if ($response.maintenance -eq $true) {
            Clear-Host
            Write-Host @"
  ____  _                        ____       _     _             _
 / ___|| |_ ___  __ _ _ __ ___  |  _ \  ___| |__ | | ___   __ _| |_
 \___ \| __/ _ \/ _` | '_ ` _ \ | | | |/ _ \ '_ \| |/ _ \ / _` | __|
  ___) | ||  __/ (_| | | | | | || |_| |  __/ |_) | | (_) | (_| | |_
 |____/ \__\___|\__,_|_| |_| |_||____/ \___|_.__/|_|\___/ \__,_|\__|

                     MAINTENANCE IN PROGRESS
"@ -ForegroundColor Red

            Write-Host "`nReason for maintenance:" -ForegroundColor Cyan
            Write-Host "$($response.message)" -ForegroundColor Yellow
            Write-Host "`nPress Enter to exit..." -ForegroundColor Cyan
            Read-Host
            exit
        }
    }
    catch {
        # If maintenance check fails, continue with the script
        return
    }
}

# Check if Steam is installed
function Test-SteamInstallation {
    $steamExePath = Join-Path $script:config.SteamInstallDir "steam.exe"
    return Test-Path $steamExePath
}

# Install Steam
function Install-Steam {
    Write-DebugLog "Downloading Steam installer..." -Level Info
    $setupPath = Join-Path $env:TEMP "SteamSetup.exe"

    try {
        Invoke-SafeWebRequest -Uri $script:config.Urls.SteamSetup -OutFile $setupPath
        Write-DebugLog "Running Steam installer..." -Level Info
        Start-Process -FilePath $setupPath -ArgumentList "/S" -Wait

        Start-Sleep -Seconds 10
        if (Test-SteamInstallation) {
            Write-DebugLog "Steam installed successfully!" -Level Success
            Remove-Item $setupPath -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-DebugLog "Steam installation may have failed. Please install manually." -Level Error
            return $false
        }
    }
    catch {
        Write-DebugLog "Failed to install Steam: $_" -Level Error
        return $false
    }
}

# Safe web request function with retry logic
function Invoke-SafeWebRequest {
    param (
        [string]$Uri,
        [string]$OutFile
    )
    $attempt = 0
    do {
        $attempt++
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return
        }
        catch {
            if ($attempt -ge $script:config.RetryAttempts) {
                throw "Failed to download from $Uri after $($script:config.RetryAttempts) attempts: $_"
            }
            Write-DebugLog "Download attempt $attempt failed. Retrying in $($script:config.RetryDelay) seconds..." -Level Warning
            Start-Sleep -Seconds $script:config.RetryDelay
        }
    } while ($true)
}

# Check for admin privileges
function Test-AdminPrivileges {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Start process as admin
function Start-ProcessAsAdmin {
    param (
        [string]$FilePath,
        [string]$ArgumentList
    )
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs -Wait
}

# Stop Steam processes
function Stop-SteamProcesses {
    $steamProcesses = Get-Process -Name "*steam*" -ErrorAction SilentlyContinue
    foreach ($process in $steamProcesses) {
        try {
            $process.Kill()
            $process.WaitForExit(5000)
            Write-DebugLog "Stopped process: $($process.ProcessName)" -Level Info
        }
        catch {
            if ($_.Exception.Message -notlike "*The process has already exited.*") {
                Write-DebugLog "Failed to stop process $($process.ProcessName): $_" -Level Warning
            }
        }
    }
}

# Get required files
function Get-RequiredFiles {
    param (
        [string]$SelectedMode
    )
    $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
    $steamCfgPath = Join-Path $env:TEMP "steam.cfg"

    Write-DebugLog "Downloading Steam-$SelectedMode.bat..." -Level Info
    Invoke-SafeWebRequest -Uri $script:config.Urls[$SelectedMode] -OutFile $steamBatPath

    Write-DebugLog "Downloading steam.cfg..." -Level Info
    Invoke-SafeWebRequest -Uri $script:config.Urls.SteamCfg -OutFile $steamCfgPath

    return @{ SteamBat = $steamBatPath; SteamCfg = $steamCfgPath }
}

# Invoke Steam update
function Invoke-SteamUpdate {
    param (
        [string]$Url
    )
    $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"
    Write-DebugLog "Updating Steam from $Url..." -Level Info
    Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments
    $timeout = 300
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        if ($timer.Elapsed.TotalSeconds -gt $timeout) {
            Write-DebugLog "Steam update process timed out after $timeout seconds." -Level Warning
            break
        }
        Start-Sleep -Seconds 5
    }
    $timer.Stop()
    Write-DebugLog "Steam update process completed in $($timer.Elapsed.TotalSeconds) seconds." -Level Info
}

# Move configuration file
function Move-ConfigFile {
    param (
        [string]$SourcePath
    )
    $destinationPath = Join-Path $script:config.SteamInstallDir "steam.cfg"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-DebugLog "Moved steam.cfg to $destinationPath" -Level Info
}

# Move Steam bat to Startup folder
function Move-SteamBatToStartup {
    param (
        [string]$SourcePath
    )
    $startupPath = [Environment]::GetFolderPath('Startup')
    $destinationPath = Join-Path $startupPath "steam.bat"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-DebugLog "Moved steam.bat to Startup folder" -Level Info
}

# Move Steam bat to desktop
function Move-SteamBatToDesktop {
    param (
        [string]$SourcePath
    )
    $destinationPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "steam.bat"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-DebugLog "Moved steam.bat to desktop" -Level Info

    if (-not $NoInteraction) {
        $startupChoice = Read-Host "Would you like to add steam.bat to Startup folder? (Y/N)"
        if ($startupChoice.ToUpper() -eq 'Y') {
            Move-SteamBatToStartup -SourcePath $destinationPath
        }
    }
}

# Remove temporary files
function Remove-TempFiles {
    Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue
    Write-DebugLog "Removed temporary files" -Level Info
}

# Main function to start Steam debloat process
function Start-SteamDebloat {
    param (
        [string]$SelectedMode
    )
    try {
        if (-not (Test-AdminPrivileges)) {
            Write-DebugLog "Requesting administrator privileges..." -Level Warning
            $scriptPath = $MyInvocation.MyCommand.Path
            $arguments = "-File `"$scriptPath`" -Mode `"$SelectedMode`""
            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                if ($param.Key -ne "Mode") {
                    $arguments += " -$($param.Key)"
                    if ($param.Value -isnot [switch]) {
                        $arguments += " `"$($param.Value)`""
                    }
                }
            }
            Start-ProcessAsAdmin -FilePath "powershell.exe" -ArgumentList $arguments
            return
        }

        $host.UI.RawUI.WindowTitle = "$($script:config.Title) - $($script:config.GitHub)"
        Write-DebugLog "Starting $($script:config.Title) Optimization in $SelectedMode mode" -Level Info

        # Check if Steam is installed
        if (-not (Test-SteamInstallation)) {
            Write-DebugLog "Steam is not installed on this system." -Level Warning
            $choice = Read-Host "Would you like to install Steam? (Y/N)"
            if ($choice.ToUpper() -eq 'Y') {
                $installSuccess = Install-Steam
                if (-not $installSuccess) {
                    Write-DebugLog "Cannot proceed without Steam installation." -Level Error
                    return
                }
            }
            else {
                Write-DebugLog "Cannot proceed without Steam installation." -Level Error
                return
            }
        }

        Stop-SteamProcesses
        $files = Get-RequiredFiles -SelectedMode $SelectedMode

        if (-not $NoInteraction -and (Read-Host "Do you want to downgrade Steam? (Y/N)").ToUpper() -eq 'Y') {
            Invoke-SteamUpdate -Url $script:config.DefaultDowngradeUrl
        }

        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat

        Remove-TempFiles

        Write-DebugLog "Steam Optimization process completed successfully!" -Level Success
        Write-DebugLog "Steam has been updated and configured for optimal performance." -Level Info
        Write-DebugLog "You can contribute to improve the repository at: $($script:config.GitHub)" -Level Info
        if (-not $NoInteraction) { Read-Host "Press Enter to exit" }
    }
    catch {
        Write-DebugLog "An error occurred: $_" -Level Error
        Write-DebugLog "For troubleshooting, visit: $($script:config.ErrorPage)" -Level Info
    }
}

# Initialize log file if debug is enabled
if ($Debug -eq "on") {
    if (Test-Path $script:config.LogFile) {
        Clear-Content $script:config.LogFile
    }
    Write-DebugLog "Debug logging enabled - Log file: $($script:config.LogFile)" -Level Info
}

# Main execution
Test-MaintenanceStatus

if (-not $SkipIntro -and -not $NoInteraction) {
    Clear-Host
    Write-Host @"
  ____  _                        ____       _     _             _
 / ___|| |_ ___  __ _ _ __ ___  |  _ \  ___| |__ | | ___   __ _| |_
 \___ \| __/ _ \/ _` | '_ ` _ \ | | | |/ _ \ '_ \| |/ _ \ / _` | __|
  ___) | ||  __/ (_| | | | | | || |_| |  __/ |_) | | (_) | (_| | |_
 |____/ \__\___|\__,_|_| |_| |_||____/ \___|_.__/|_|\___/ \__,_|\__|
"@ -ForegroundColor Cyan
    Write-DebugLog "`nWelcome to $($script:config.Title) - $($script:config.GitHub) - $($script:config.Version)`n" -Level Info
    $Mode = Read-Host "Choose mode (Normal/Lite/TEST)"
}

Start-SteamDebloat -SelectedMode $Mode
