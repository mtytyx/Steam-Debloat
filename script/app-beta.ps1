[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Normal", "Lite", "TEST", "TEST-Lite", "TEST-Version")]
    [string]$Mode = "Normal",
    [switch]$SkipIntro,
    [switch]$NoInteraction,
    [switch]$PerformanceMode,
    [switch]$AdvancedCleaning,
    [switch]$DisableUpdates,
    [string]$CustomVersion,
    [string]$LogLevel = "Info"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx/Steam-Debloat"
    Version = "v7.0"
    Color = @{Info = "Cyan"; Success = "Green"; Warning = "Yellow"; Error = "Red"; Debug = "Magenta"}
    ErrorPage = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls = @{
        "Normal" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "TEST" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "TEST-Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat"
        "TEST-Version" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    LogFile = Join-Path $env:USERPROFILE "Desktop\Steam-Debloat.log"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    RetryAttempts = 3
    RetryDelay = 5
    PerformanceTweaks = @{
        DisableOverlay = $true
        DisableVoiceChat = $true
        OptimizeNetworkConfig = $true
    }
}


function Write-Log {
    param ([string]$Message, [string]$Level = "Info", [switch]$NoNewline)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    $color = $script:config.Color[$Level]
    if ($NoNewline) { Write-Host -NoNewline "[$Level] $Message" -ForegroundColor $color }
    else { Write-Host "[$Level] $Message" -ForegroundColor $color }
    Add-Content -Path $script:config.LogFile -Value $logMessage
}

function Invoke-SafeWebRequest {
    param ([string]$Uri, [string]$OutFile)
    $attempt = 0
    do {
        $attempt++
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return
        } catch {
            if ($attempt -ge $script:config.RetryAttempts) { throw }
            Start-Sleep -Seconds $script:config.RetryDelay
        }
    } while ($true)
}

function Test-AdminPrivileges { return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }

function Start-ProcessAsAdmin {
    param ([string]$FilePath, [string]$ArgumentList)
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs -Wait
}

function Stop-SteamProcesses {
    Get-Process | Where-Object { $_.Name -like "*steam*" } | ForEach-Object {
        try { $_.Kill(); $_.WaitForExit(5000) }
        catch { Write-Log "Failed to stop process $($_.Name): $_" -Level Warning }
    }
}

function Get-Files {
    param ([string]$SelectedMode)
    $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
    $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
    Invoke-SafeWebRequest -Uri $script:config.Urls[$SelectedMode] -OutFile $steamBatPath
    Invoke-SafeWebRequest -Uri $script:config.Urls.SteamCfg -OutFile $steamCfgPath
    return @{ SteamBat = $steamBatPath; SteamCfg = $steamCfgPath }
}

function Invoke-SteamUpdate {
    param ([string]$Url)
    $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"
    Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments
    $timeout = 300
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        if ($timer.Elapsed.TotalSeconds -gt $timeout) { break }
        Start-Sleep -Seconds 5
    }
    $timer.Stop()
}

function Move-ConfigFile {
    param ([string]$SourcePath)
    Copy-Item -Path $SourcePath -Destination (Join-Path $script:config.SteamInstallDir "steam.cfg") -Force
}

function Move-SteamBatToDesktop {
    param ([string]$SourcePath, [string]$SelectedMode)
    Copy-Item -Path $SourcePath -Destination (Join-Path ([Environment]::GetFolderPath("Desktop")) "Steam-$SelectedMode.bat") -Force
}

function Remove-TempFiles {
    Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue
}

function Optimize-SteamPerformance {
    if ($script:config.PerformanceTweaks.DisableOverlay) {
        Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "GameOverlayDisabled" -Value 1 -Type DWord
    }
    if ($script:config.PerformanceTweaks.DisableVoiceChat) {
        Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "VoiceReceiveVolume" -Value 0 -Type DWord
    }
    if ($script:config.PerformanceTweaks.OptimizeNetworkConfig) {
        $libraryFoldersPath = Join-Path $script:config.SteamInstallDir "steamapps\libraryfolders.vdf"
        if (Test-Path $libraryFoldersPath) {
            (Get-Content $libraryFoldersPath -Raw) -replace '("MaximumConnectionsPerServer"\s+")(\d+)(")', '$1128$3' | Set-Content $libraryFoldersPath -Force
        }
    }
}

function Invoke-AdvancedCleaning {
    Remove-Item -Path "$($script:config.SteamInstallDir)\steamapps\downloading\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$($script:config.SteamInstallDir)\steamapps\shadercache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Steam\htmlcache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$($script:config.SteamInstallDir)\steamapps" -Filter "*.old" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Disable-SteamUpdates {
    @"
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
"@ | Set-Content (Join-Path $script:config.SteamInstallDir "steam.cfg") -Force
}

function Start-SteamDebloat {
    param ([string]$SelectedMode)
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

        Stop-SteamProcesses
        $files = Get-Files -SelectedMode $SelectedMode

        if ($CustomVersion -or (-not $NoInteraction -and (Read-Host "Do you want to downgrade Steam? (Y/N)").ToUpper() -eq 'Y')) {
            $downgradeUrl = if ($CustomVersion) { $CustomVersion } else { $script:config.DefaultDowngradeUrl }
            Invoke-SteamUpdate -Url $downgradeUrl
        }

        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode

        if ($PerformanceMode) { Optimize-SteamPerformance }
        if ($AdvancedCleaning) { Invoke-AdvancedCleaning }
        if ($DisableUpdates) { Disable-SteamUpdates }

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
