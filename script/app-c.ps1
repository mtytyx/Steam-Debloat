[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Normal", "Lite", "TEST", "TEST-Lite", "TEST-Version")]
    [string]$Mode = "Normal",
    [switch]$SkipIntro,
    [switch]$NoInteraction,
    [string]$CustomVersion,
    [string]$LogLevel = "Info"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$script:config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx/Steam-Debloat"
    Version = "v7.8"
    Color = @{Info = "Green"; Success = "Green"; Warning = "Yellow"; Error = "Red"; Debug = "Green"}
    ErrorPage = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls = @{
        "Normal" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "TEST" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "TEST-Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat"
        "TEST-Version" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
        "SteamSetup" = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    LogFile = Join-Path $env:TEMP "Steam-Debloat.log"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    RetryAttempts = 3
    RetryDelay = 5
}

# Check if Steam is installed
function Test-SteamInstallation {
    $steamExePath = Join-Path $script:config.SteamInstallDir "steam.exe"
    return Test-Path $steamExePath
}

# Install Steam
function Install-Steam {
    Write-Log "Downloading Steam installer..." -Level Info
    $setupPath = Join-Path $env:TEMP "SteamSetup.exe"
    
    try {
        Invoke-SafeWebRequest -Uri $script:config.Urls.SteamSetup -OutFile $setupPath
        Write-Log "Running Steam installer..." -Level Info
        Start-Process -FilePath $setupPath -ArgumentList "/S" -Wait
        
        # Wait for installation to complete and verify
        Start-Sleep -Seconds 10
        if (Test-SteamInstallation) {
            Write-Log "Steam installed successfully!" -Level Success
            Remove-Item $setupPath -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Log "Steam installation may have failed. Please install manually." -Level Error
            return $false
        }
    } catch {
        Write-Log "Failed to install Steam: $_" -Level Error
        return $false
    }
}

# Logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoNewline
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    $color = $script:config.Color[$Level]
    if ($NoNewline) {
        Write-Host -NoNewline "[$Level] $Message" -ForegroundColor $color -Background "DarkBlue" -Verbose
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $color -BackgroundColor Black -Verbose
    }
    Add-Content -Path $script:config.LogFile -Value $logMessage
}

# [Rest of the existing functions remain the same...]

# Updated Main function to start Steam debloat process
function Start-SteamDebloat {
    param (
        [string]$SelectedMode
    )
    try {
        if (-not (Test-AdminPrivileges)) {
            Write-Log "Requesting administrator privileges..." -Level Warning
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
        Write-Log "Starting $($script:config.Title) Optimization in $SelectedMode mode" -Level Info

        # Check if Steam is installed
        if (-not (Test-SteamInstallation)) {
            Write-Log "Steam is not installed on this system." -Level Warning
            $choice = Read-Host "Would you like to install Steam? (Y/N)"
            if ($choice.ToUpper() -eq 'Y') {
                $installSuccess = Install-Steam
                if (-not $installSuccess) {
                    Write-Log "Cannot proceed without Steam installation." -Level Error
                    return
                }
            } else {
                Write-Log "Cannot proceed without Steam installation." -Level Error
                return
            }
        }

        Stop-SteamProcesses
        $files = Get-RequiredFiles -SelectedMode $SelectedMode

        if ($SelectedMode -eq "TEST-Version") {
            if (-not $CustomVersion) {
                $CustomVersion = Read-Host "Enter the custom version URL for Steam update"
            }
            if ($CustomVersion) {
                Invoke-SteamUpdate -Url $CustomVersion
            } else {
                Write-Log "No custom version URL provided. Skipping Steam update." -Level Warning
            }
        } elseif (-not $NoInteraction -and (Read-Host "Do you want to downgrade Steam? (Y/N)").ToUpper() -eq 'Y') {
            Invoke-SteamUpdate -Url $script:config.DefaultDowngradeUrl
        }

        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode

        Remove-TempFiles

        Write-Log "Steam Optimization process completed successfully!" -Level Success
        Write-Log "Steam has been updated and configured for optimal performance." -Level Info
        Write-Log "You can contribute to improve the repository at: $($script:config.GitHub)" -Level Info
        if (-not $NoInteraction) { Read-Host "Press Enter to exit" }
    } catch {
        Write-Log "An error occurred: $_" -Level Error
        Write-Log "For troubleshooting, visit: $($script:config.ErrorPage)" -Level Info
    }
}

# Main execution
if (-not $SkipIntro -and -not $NoInteraction) {
    Clear-Host
    Write-Host @"
  ____  _                        ____       _     _             _
 / ___|| |_ ___  __ _ _ __ ___  |  _ \  ___| |__ | | ___   __ _| |_
 \___ \| __/ _ \/ _` | '_ ` _ \ | | | |/ _ \ '_ \| |/ _ \ / _` | __|
  ___) | ||  __/ (_| | | | | | || |_| |  __/ |_) | | (_) | (_| | |_
 |____/ \__\___|\__,_|_| |_| |_||____/ \___|_.__/|_|\___/ \__,_|\__|
"@ -ForegroundColor Cyan
    Write-Log "`nWelcome to $($script:config.Title) - $($script:config.GitHub) - $($script:config.Version)`n" -Level Info
    $Mode = Read-Host "Choose mode (Normal/Lite/TEST/TEST-Lite/TEST-Version)"
}

Start-SteamDebloat -SelectedMode $Mode
