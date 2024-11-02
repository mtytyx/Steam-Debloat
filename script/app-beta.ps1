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

#region Configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Enhanced configuration settings
$script:config = @{
    Title = "Steam Debloat Professional"
    GitHub = "Github.com/mtytyx/Steam-Debloat"
    Version = "v8.0"
    Color = @{
        Info = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Debug = "Magenta"
        Title = "DarkCyan"
        Highlight = "White"
    }
    ErrorPage = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls = @{
        "Normal" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "TEST" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "TEST-Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat"
        "TEST-Version" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
        "MaintenanceStatus" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/maintenance.json"
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    LogFile = Join-Path $env:USERPROFILE "Desktop\Steam-Debloat.log"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    RetryAttempts = 3
    RetryDelay = 5
    UpdateTimeout = 300
}
#endregion

#region Helper Functions
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoNewline,
        [switch]$NoTimestamp
    )
    
    $timestamp = if (-not $NoTimestamp) { "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] " } else { "" }
    $logMessage = "$timestamp[$Level] $Message"
    $color = $script:config.Color[$Level]
    
    if ($NoNewline) {
        Write-Host -NoNewline $Message -ForegroundColor $color
    } else {
        Write-Host $Message -ForegroundColor $color
    }
    
    Add-Content -Path $script:config.LogFile -Value $logMessage
}

function Write-Banner {
    Clear-Host
    $banner = @"
    ╔═══════════════════════════════════════════════════════════════╗
    ║  _____ _                        ____       _     _            ║
    ║ / ____| |                      |  _ \     | |   | |          ║
    ║| (___ | |_ ___  __ _ _ __ ___ | |_) | ___| |__ | | ___  __ _║
    ║ \___ \| __/ _ \/ _` | '_ ` _ \|  _ < / _ \ '_ \| |/ _ \/ _` ║
    ║ ____) | ||  __/ (_| | | | | | | |_) |  __/ |_) | |  __/ (_| ║
    ║|_____/ \__\___|\__,_|_| |_| |_|____/ \___|_.__/|_|\___|\__,_║
    ║                                                               ║
    ║                    Professional Edition v8.0                  ║
    ╚═══════════════════════════════════════════════════════════════╝
"@
    Write-Host $banner -ForegroundColor $script:config.Color.Title
    Write-Log "`nWelcome to $($script:config.Title) Professional - $($script:config.GitHub) - $($script:config.Version)`n" -Level Info -NoTimestamp
}

function Show-Progress {
    param (
        [string]$Activity,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -PercentComplete $PercentComplete
}

function Invoke-SafeWebRequest {
    param (
        [string]$Uri,
        [string]$OutFile
    )
    
    $attempt = 0
    do {
        $attempt++
        Show-Progress -Activity "Downloading $([System.IO.Path]::GetFileName($OutFile))" -PercentComplete (($attempt / $script:config.RetryAttempts) * 100)
        
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            Write-Log "Successfully downloaded: $([System.IO.Path]::GetFileName($OutFile))" -Level Success
            return
        } catch {
            if ($attempt -ge $script:config.RetryAttempts) {
                throw "Failed to download from $Uri after $($script:config.RetryAttempts) attempts: $_"
            }
            Write-Log "Download attempt $attempt failed. Retrying in $($script:config.RetryDelay) seconds..." -Level Warning
            Start-Sleep -Seconds $script:config.RetryDelay
        }
    } while ($true)
}
#endregion

#region Core Functions
function Test-AdminPrivileges {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ProcessAsAdmin {
    param (
        [string]$FilePath,
        [string]$ArgumentList
    )
    
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs -Wait
}

function Stop-SteamProcesses {
    Write-Log "Stopping Steam processes..." -Level Info
    $steamProcesses = Get-Process | Where-Object { $_.Name -like "*steam*" }
    
    if ($steamProcesses) {
        foreach ($process in $steamProcesses) {
            try {
                $process.Kill()
                $process.WaitForExit(5000)
                Write-Log "Stopped process: $($process.Name)" -Level Success
            } catch {
                Write-Log "Failed to stop process $($process.Name): $_" -Level Warning
            }
        }
    } else {
        Write-Log "No Steam processes found running" -Level Info
    }
}

function Get-RequiredFiles {
    param (
        [string]$SelectedMode
    )
    
    $files = @{
        SteamBat = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
        SteamCfg = Join-Path $env:TEMP "steam.cfg"
    }
    
    Write-Log "Downloading required files..." -Level Info
    Invoke-SafeWebRequest -Uri $script:config.Urls[$SelectedMode] -OutFile $files.SteamBat
    Invoke-SafeWebRequest -Uri $script:config.Urls.SteamCfg -OutFile $files.SteamCfg
    
    return $files
}

function Invoke-SteamUpdate {
    param (
        [string]$Url
    )
    
    $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"
    Write-Log "Updating Steam from $Url..." -Level Info
    
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments
    
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        if ($timer.Elapsed.TotalSeconds -gt $script:config.UpdateTimeout) {
            Write-Log "Steam update process timed out after $($script:config.UpdateTimeout) seconds." -Level Warning
            break
        }
        Show-Progress -Activity "Updating Steam" -PercentComplete (($timer.Elapsed.TotalSeconds / $script:config.UpdateTimeout) * 100)
        Start-Sleep -Seconds 5
    }
    
    $timer.Stop()
    Write-Log "Steam update process completed in $($timer.Elapsed.TotalSeconds) seconds." -Level Success
}

function Move-ConfigFile {
    param (
        [string]$SourcePath
    )
    
    $destinationPath = Join-Path $script:config.SteamInstallDir "steam.cfg"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-Log "Configuration file moved to Steam directory" -Level Success
}

function Move-SteamBatToDesktop {
    param (
        [string]$SourcePath,
        [string]$SelectedMode
    )
    
    $destinationPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Steam-$SelectedMode.bat"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-Log "Steam optimization script moved to desktop" -Level Success
}

function Remove-TempFiles {
    Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue
    Write-Log "Temporary files cleaned up" -Level Success
}
#endregion

#region Main Function
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

        $host.UI.RawUI.WindowTitle = "$($script:config.Title) Professional - $($script:config.GitHub)"
        Write-Log "`nStarting Steam optimization in $SelectedMode mode" -Level Info

        # Main process steps
        Stop-SteamProcesses
        $files = Get-RequiredFiles -SelectedMode $SelectedMode

        if ($SelectedMode -eq "TEST-Version") {
            if (-not $CustomVersion) {
                $CustomVersion = Read-Host "`nEnter custom Steam version URL"
            }
            if ($CustomVersion) {
                Invoke-SteamUpdate -Url $CustomVersion
            } else {
                Write-Log "No custom version URL provided. Skipping update." -Level Warning
            }
        } elseif (-not $NoInteraction -and (Read-Host "`nDo you want to downgrade Steam? (Y/N)").ToUpper() -eq 'Y') {
            Invoke-SteamUpdate -Url $script:config.DefaultDowngradeUrl
        }

        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode
        Remove-TempFiles

        Write-Log "`nSteam optimization completed successfully!" -Level Success
        Write-Log "Steam has been configured for optimal performance" -Level Info
        Write-Log "You can contribute to improve this tool at: $($script:config.GitHub)" -Level Info

        if (-not $NoInteraction) {
            Read-Host "`nPress Enter to exit"
        }
    } catch {
        Write-Log "`nAn error occurred: $_" -Level Error
        Write-Log "For troubleshooting, visit: $($script:config.ErrorPage)" -Level Info
        if (-not $NoInteraction) {
            Read-Host "`nPress Enter to exit"
        }
    }
}
#endregion

#region Script Execution
if (-not $SkipIntro -and -not $NoInteraction) {
    Write-Banner
    $Mode = Read-Host "`nChoose mode (Normal/Lite/TEST/TEST-Lite/TEST-Version)"
}

Start-SteamDebloat -SelectedMode $Mode
#endregion
