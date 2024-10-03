[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Normal", "Lite", "TEST", "TEST-Lite", "TEST-Version")]
    [string]$Mode = $null,

    [switch]$SkipIntro,
    [switch]$ForceBackup,
    [switch]$SkipDowngrade,
    [string]$CustomVersion,
    [switch]$NoInteraction,
    [switch]$PerformanceMode,
    [switch]$AdvancedCleaning,
    [switch]$DisableUpdates,
    [int]$BackupRetention = 5,
    [string]$LogLevel = "Info"
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management

# Configuration
$script:config = @{
    Title = "Steam"
    GitHub = "Github.com/mtytyx"
    Version = @{
        ps1 = "v7.5"
        Stable = "v4.2"
        Beta = "v4.4"
    }
    Color = @{
        Info = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Debug = "Magenta"
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
    # testing url change to speed up the downgrade process
    DefaultDowngradeUrl = "https://huggingface.co/spaces/mtytyx/RepoGit/resolve/main/dec2022steam.zip"
    # vc++ installer url taken from the famous abbodi1406 repository https://github.com/abbodi1406/vcredist
    VCRedistUrl = "https://github.com/abbodi1406/vcredist/releases/latest/download/VisualCppRedist_AIO_x86_x64.exe"
    # official url of the steam download button
    SteamSetupUrl = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
    LogFile = Join-Path $env:USERPROFILE "Desktop\Steam-Debloat.log"
    BackupDir = Join-Path $env:USERPROFILE "Steam-DebloatBackup"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    MaxBackups = $BackupRetention
    RetryAttempts = 5
    RetryDelay = 10
    PerformanceTweaks = @{
        DisableOverlay = $true
        LowViolence = $false
        DisableVoiceChat = $true
        OptimizeNetworkConfig = $true
    }
}

# Enhanced Logging Function with Log Rotation
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Message,
        
        [Parameter(Position=1)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info",
        
        [Parameter(Position=2)]
        [int]$Delay = 10,
        
        [switch]$NoNewline
    )
    
    if ($Level -eq "Debug" -and $LogLevel -ne "Debug") {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with color
    $color = $script:config.Color[$Level]
    Write-Host -NoNewline "["
    Write-Host -NoNewline $Level.ToUpper() -ForegroundColor $color
    Write-Host -NoNewline "] "
    
    if ($NoNewline) {
        Write-Host -NoNewline $Message
    } else {
        if (-not $NoInteraction) {
            foreach ($char in $Message.ToCharArray()) {
                Write-Host -NoNewline $char
                Start-Sleep -Milliseconds $Delay
            }
            Write-Host ""
        } else {
            Write-Host $Message
        }
    }
    
    # Append to log file with rotation
    $logFile = $script:config.LogFile
    Add-Content -Path $logFile -Value $logMessage
    
    # Rotate log if it exceeds 10MB
    if ((Get-Item $logFile).Length -gt 10MB) {
        $backupLog = "$logFile.1"
        if (Test-Path $backupLog) {
            Remove-Item $backupLog -Force
        }
        Rename-Item $logFile $backupLog
        New-Item $logFile -ItemType File
    }
    
    # If verbose mode is on, provide more details for debugging
    if ($VerbosePreference -eq 'Continue' -and $Level -eq "Debug") {
        $callStack = Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object { "$($_.FunctionName) - $($_.ScriptLineNumber)" }
        $debugInfo = "  Call Stack: $($callStack -join ' -> ')"
        Write-Host $debugInfo -ForegroundColor $script:config.Color.Debug
        Add-Content -Path $logFile -Value $debugInfo
    }
}

function Invoke-SafeWebRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter(Mandatory=$true)]
        [string]$OutFile,
        
        [int]$MaxRetries = $script:config.RetryAttempts,
        [int]$RetryDelaySeconds = $script:config.RetryDelay
    )
    
    $attempt = 0
    do {
        $attempt++
        try {
            Write-Log "Attempting download from $Uri (Attempt $attempt of $MaxRetries)" -Level Debug
            $response = Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            Write-Log "Successfully downloaded file from $Uri" -Level Success
            return $response
        }
        catch {
            Write-Log "Attempt $attempt failed: $_" -Level Warning
            if ($attempt -lt $MaxRetries) {
                Write-Log "Retrying in $RetryDelaySeconds seconds..." -Level Info
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                throw "Failed to download file from $Uri after $MaxRetries attempts. Error: $_"
            }
        }
    } while ($attempt -lt $MaxRetries)
}

function Test-AdminPrivileges {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ProcessAsAdmin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ArgumentList
    )
    
    try {
        Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs -Wait
    }
    catch {
        throw "Failed to start process as admin: $_"
    }
}

function Show-Introduction {
    Clear-Host
    $art = @"
  ____  _                        
 / ___|| |_ ___  __ _ _ __ ___   
 \___ \| __/ _ \/ _` | '_ ` _ \  
  ___) | ||  __/ (_| | | | | | | 
 |____/ \__\___|\__,_|_| |_| |_| 
                                 
  ____       _     _             _   
 |  _ \  ___| |__ | | ___   __ _| |_ 
 | | | |/ _ \ '_ \| |/ _ \ / _` | __|
 | |_| |  __/ |_) | | (_) | (_| | |_ 
 |____/ \___|_.__/|_|\___/ \__,_|\__|
                                     
"@
    Write-Host $art -ForegroundColor Cyan
    Write-Log "`nWelcome to $($script:config.Title) - $($script:config.GitHub) - $($script:config.Version.ps1) `n" -Level Info
    Write-Log "This advanced script optimizes and enhances Steam for superior performance." -Level Info
    Write-Log "------------------------------------------------" -Level Info
    Write-Log "1. Steam Optimization Stable (Version $($script:config.Version.Stable))" -Level Info
    Write-Log "2. Steam Optimization Beta (Version $($script:config.Version.Beta))" -Level Info
    Write-Log "------------------------------------------------`n" -Level Info
}

function Get-UserSelection {
    do {
        $choice = Read-Host "Please choose an option (1 or 2)"
        switch ($choice) {
            1 {
                $selectedMode = Read-Host "Choose mode: Normal or Lite"
                if ($selectedMode -notin @("Normal", "Lite")) {
                    Write-Log "Invalid choice. Please try again." -Level Error
                    continue
                }
            }
            2 { 
                Write-Log "You have entered beta mode. you will not receive support on issues." -Level Warning
                $selectedMode = Read-Host "Choose mode: TEST, TEST-Lite, or TEST-Version"
                if ($selectedMode -notin @("TEST", "TEST-Lite", "TEST-Version")) {
                    Write-Log "Invalid choice. Please try again." -Level Error
                    continue
                }
            }
            default {
                Write-Log "Invalid choice. Please try again." -Level Error
                continue
            }
        }
        return $selectedMode
    } while ($true)
}

function Initialize-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SelectedMode
    )
    
    $host.UI.RawUI.WindowTitle = "$($script:config.Title) - $($script:config.GitHub)"
    $version = if ($SelectedMode -like "TEST*") { $script:config.Version.Beta } else { $script:config.Version.Stable }
    Write-Log "Starting $($script:config.Title) Optimization in $SelectedMode mode" -Level Info
    
    if (-not (Test-AdminPrivileges)) {
        Write-Log "Requesting administrator privileges..." -Level Warning
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = "-File `"$scriptPath`" -Mode `"$SelectedMode`""
        if ($SkipIntro) { $arguments += " -SkipIntro" }
        if ($ForceBackup) { $arguments += " -ForceBackup" }
        if ($SkipDowngrade) { $arguments += " -SkipDowngrade" }
        if ($CustomVersion) { $arguments += " -CustomVersion `"$CustomVersion`"" }
        if ($NoInteraction) { $arguments += " -NoInteraction" }
        if ($PerformanceMode) { $arguments += " -PerformanceMode" }
        if ($AdvancedCleaning) { $arguments += " -AdvancedCleaning" }
        if ($DisableUpdates) { $arguments += " -DisableUpdates" }
        if ($VerbosePreference -eq 'Continue') { $arguments += " -Verbose" }
        
        Start-ProcessAsAdmin -FilePath "powershell.exe" -ArgumentList $arguments
        exit
    }
}

function Stop-SteamProcesses {
    Write-Log "Stopping Steam processes..." -Level Info
    $steamProcesses = Get-Process | Where-Object { $_.Name -like "*steam*" }
    
    if ($steamProcesses) {
        foreach ($process in $steamProcesses) {
            try {
                $process.Kill()
                $process.WaitForExit(5000)
                Write-Log "Stopped process: $($process.Name)" -Level Debug
            }
            catch {
                Write-Log "Failed to stop process $($process.Name): $_" -Level Warning
            }
        }
        
        # Wait for all Steam processes to close
        $timeout = 300 # 5 minutes timeout
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (Get-Process | Where-Object { $_.Name -like "*steam*" }) {
            if ($timer.Elapsed.TotalSeconds -gt $timeout) {
                Write-Log "Timeout reached. Some Steam processes could not be closed." -Level Warning
                break
            }
            Start-Sleep -Seconds 5
        }
        $timer.Stop()
    }
    else {
        Write-Log "No Steam processes found running." -Level Info
    }
}

function Get-Files {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SelectedMode
    )
    
    Write-Log "Downloading required files for $SelectedMode mode..." -Level Info
    
    $steamBatUrl = $script:config.Urls[$SelectedMode].SteamBat
    $steamCfgUrl = $script:config.Urls.SteamCfg
    
    try {
        $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
        Invoke-SafeWebRequest -Uri $steamBatUrl -OutFile $steamBatPath
        Write-Log "Successfully downloaded Steam-$SelectedMode.bat" -Level Success
        
        $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
        Invoke-SafeWebRequest -Uri $steamCfgUrl -OutFile $steamCfgPath
        Write-Log "Successfully downloaded steam.cfg" -Level Success
        
        return @{
            SteamBat = $steamBatPath
            SteamCfg = $steamCfgPath
        }
    }
    catch {
        throw "Failed to download files. Error: $_"
    }
}

function Get-LatestVCRedistVersion {
    $releaseUrl = "https://api.github.com/repos/abbodi1406/vcredist/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl
    return $release.tag_name
}

function Install-VCRedistAIO {
    Write-Log "Downloading and installing VC++ AIO..." -Level Info
    $vcRedistPath = Join-Path $env:TEMP "VisualCppRedist_AIO_x86_x64.exe"
    
    try {
        $latestVersion = Get-LatestVCRedistVersion
        Write-Log "Latest VC++ AIO version: $latestVersion" -Level Info
        
        Invoke-SafeWebRequest -Uri $script:config.VCRedistUrl -OutFile $vcRedistPath
        Write-Log "VC++ AIO downloaded successfully" -Level Success
        
        Start-Process -FilePath $vcRedistPath -Wait
        Write-Log "VC++ AIO installed successfully" -Level Success
    }
    catch {
        throw "Failed to download or install VC++ AIO: $_"
    }
    finally {
        Remove-Item -Path $vcRedistPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SteamUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url
    )
    
    Write-Log "Starting Steam update process..." -Level Info
    $downgradeZipPath = Join-Path $env:TEMP "dec2022steam.zip"
    $extractPath = Join-Path $env:TEMP "dec2022steam"
    
    try {
        Invoke-SafeWebRequest -Uri $Url -OutFile $downgradeZipPath
        Expand-Archive -Path $downgradeZipPath -DestinationPath $extractPath -Force
        
        $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl `"$extractPath`" -exitsteam"
        Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments
        
        Write-Log "Waiting for Steam to close..." -Level Info
        $timeout = 1800 # 30 minutes timeout
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
            if ($timer.Elapsed.TotalSeconds -gt $timeout) {
                Write-Log "Timeout reached. Steam process did not close." -Level Warning
                break
            }
            Start-Sleep -Seconds 10
            Write-Log "Still waiting for Steam to close... (Elapsed time: $($timer.Elapsed.TotalMinutes.ToString("F2")) minutes)" -Level Info
        }
        $timer.Stop()
        
        Write-Log "Steam update process completed." -Level Success
        Write-Log "IMPORTANT: You will need to log in to Steam again due to the downgrade process." -Level Warning
    }
    catch {
        throw "Failed to update Steam: $_"
    }
    finally {
        Remove-Item -Path $downgradeZipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Backup-SteamFiles {
    Write-Log "Starting Steam backup process..." -Level Info
    $backupPath = Join-Path $script:config.BackupDir (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    
    try {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        
        # Use robocopy for efficient copying
        $robocopyArgs = @(
            $script:config.SteamInstallDir,
            $backupPath,
            "/E",
            "/Z",
            "/MT:16",
            "/R:3",
            "/W:10",
            "/NP",
            "/NFL",
            "/NDL"
        )
        
        $robocopyResult = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
        
        if ($robocopyResult.ExitCode -lt 8) {
            Write-Log "Steam backup created successfully at $backupPath" -Level Success
        } else {
            throw "Robocopy encountered errors during backup. Exit code: $($robocopyResult.ExitCode)"
        }
        
        # Remove old backups if exceed MaxBackups
        $backups = Get-ChildItem -Path $script:config.BackupDir | Sort-Object CreationTime -Descending
        if ($backups.Count -gt $script:config.MaxBackups) {
            $backupsToRemove = $backups | Select-Object -Skip $script:config.MaxBackups
            foreach ($backup in $backupsToRemove) {
                Remove-Item -Path $backup.FullName -Recurse -Force
                Write-Log "Removed old backup: $($backup.FullName)" -Level Info
            }
        }
    }
    catch {
        throw "Failed to create Steam backup: $_"
    }
}

function Restore-SteamFiles {
    Write-Log "Starting Steam restore process..." -Level Info
    $latestBackup = Get-ChildItem -Path $script:config.BackupDir | Sort-Object CreationTime -Descending | Select-Object -First 1
    
    if ($null -eq $latestBackup) {
        Write-Log "No backup found to restore." -Level Warning
        return
    }
    
    try {
        Stop-SteamProcesses
        
        # Use robocopy for efficient restoration
        $robocopyArgs = @(
            $latestBackup.FullName,
            $script:config.SteamInstallDir,
            "/E",
            "/Z",
            "/MT:16",
            "/R:3",
            "/W:10",
            "/NP",
            "/NFL",
            "/NDL",
            "/PURGE"
        )
        
        $robocopyResult = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
        
        if ($robocopyResult.ExitCode -lt 8) {
            Write-Log "Steam files restored successfully from $($latestBackup.FullName)" -Level Success
        } else {
            throw "Robocopy encountered errors during restoration. Exit code: $($robocopyResult.ExitCode)"
        }
    }
    catch {
        throw "Failed to restore Steam files: $_"
    }
}

function Move-ConfigFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath
    )
    
    $destinationPath = Join-Path $script:config.SteamInstallDir "steam.cfg"
    
    try {
        Copy-Item -Path $SourcePath -Destination $destinationPath -Force
        Write-Log "Moved steam.cfg to Steam installation directory" -Level Success
    }
    catch {
        throw "Failed to move steam.cfg: $_"
    }
}

function Move-SteamBatToDesktop {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$SelectedMode
    )
    
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $destinationPath = Join-Path $desktopPath "Steam-$SelectedMode.bat"
    
    try {
        Copy-Item -Path $SourcePath -Destination $destinationPath -Force
        Write-Log "Moved Steam-$SelectedMode.bat to desktop" -Level Success
    }
    catch {
        throw "Failed to move Steam-$SelectedMode.bat to desktop: $_"
    }
}

function Remove-TempFiles {
    Write-Log "Cleaning up temporary files..." -Level Info
    
    try {
        Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue
        Write-Log "Temporary files cleaned up successfully" -Level Success
    }
    catch {
        Write-Log "Failed to clean up some temporary files: $_" -Level Warning
    }
}

function Optimize-SteamPerformance {
    Write-Log "Applying performance optimizations..." -Level Info
    
    try {
        # Disable Steam Overlay
        if ($script:config.PerformanceTweaks.DisableOverlay) {
            Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "GameOverlayDisabled" -Value 1 -Type DWord
            Write-Log "Disabled Steam Overlay" -Level Success
        }
        
        # Enable Low Violence mode (if configured)
        if ($script:config.PerformanceTweaks.LowViolence) {
            Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "LowViolence" -Value 1 -Type DWord
            Write-Log "Enabled Low Violence mode" -Level Success
        }
        
        # Disable Voice Chat
        if ($script:config.PerformanceTweaks.DisableVoiceChat) {
            Set-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "VoiceReceiveVolume" -Value 0 -Type DWord
            Write-Log "Disabled Voice Chat" -Level Success
        }
        
        # Optimize Network Configuration
        if ($script:config.PerformanceTweaks.OptimizeNetworkConfig) {
            $libraryFoldersPath = Join-Path $script:config.SteamInstallDir "steamapps\libraryfolders.vdf"
            if (Test-Path $libraryFoldersPath) {
                $content = Get-Content $libraryFoldersPath -Raw
                $content = $content -replace '("MaximumConnectionsPerServer"\s+")(\d+)(")', '$1128$3'
                $content | Set-Content $libraryFoldersPath -Force
                Write-Log "Optimized network configuration" -Level Success
            } else {
                Write-Log "Could not find libraryfolders.vdf. Skipping network optimization." -Level Warning
            }
        }
        
        Write-Log "Performance optimizations applied successfully" -Level Success
    }
    catch {
        throw "Failed to apply performance optimizations: $_"
    }
}

function Invoke-AdvancedCleaning {
    Write-Log "Performing advanced cleaning..." -Level Info
    
    try {
        # Clear download cache
        Remove-Item -Path "$($script:config.SteamInstallDir)\steamapps\downloading\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear shader cache
        Remove-Item -Path "$($script:config.SteamInstallDir)\steamapps\shadercache\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear Steam browser cache
        $browserCachePath = "$env:LOCALAPPDATA\Steam\htmlcache"
        if (Test-Path $browserCachePath) {
            Remove-Item -Path "$browserCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Clear old installation files
        Get-ChildItem -Path "$($script:config.SteamInstallDir)\steamapps" -Filter "*.old" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        
        Write-Log "Advanced cleaning completed successfully" -Level Success
    }
    catch {
        Write-Log "Error during advanced cleaning: $_" -Level Warning
    }
}

function Disable-SteamUpdates {
    Write-Log "Disabling automatic Steam updates..." -Level Info
    
    try {
        $steamCfgPath = Join-Path $script:config.SteamInstallDir "steam.cfg"
        $content = @"
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
"@
        $content | Set-Content $steamCfgPath -Force
        Write-Log "Automatic Steam updates disabled" -Level Success
    }
    catch {
        throw "Failed to disable Steam updates: $_"
    }
}

function Start-SteamDebloat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SelectedMode
    )
    
    try {
        Initialize-Environment -SelectedMode $SelectedMode
        
        if (-not $NoInteraction) {
            Write-Host "WARNING: THIS BACKUP WILL INCLUDE YOUR ENTIRE STEAM DIRECTORY." -ForegroundColor Yellow
            Write-Host "IF YOU HAVE HEAVY GAMES INSTALLED, THIS PROCEDURE MAY TAKE MORE THAN 10 HOURS." -ForegroundColor Yellow
            Write-Host ""
        }

        if ($ForceBackup -or (-not $NoInteraction -and (Read-Host "Do you want to create a backup before proceeding? (Y/N)").ToUpper() -eq 'Y')) {
            Backup-SteamFiles
        }
        
        Stop-SteamProcesses
        
        $files = Get-Files -SelectedMode $SelectedMode
        
                if (-not $NoInteraction) {
            Write-Host "It is not necessary because almost all games are installed by those who request the game." -ForegroundColor Yellow
            Write-Host "This option is only in case you want to install all vc++ and not just some." -ForegroundColor Yellow
            Write-Host ""
        }
        
        if (-not $NoInteraction -and (Read-Host "Do you want to install VC++ AIO for better performance?( (Y/N)").ToUpper() -eq 'Y') {
            Install-VCRedistAIO
        }
        
        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode
        
        if ($PerformanceMode) {
            Optimize-SteamPerformance
        }
        
        if ($AdvancedCleaning) {
            Invoke-AdvancedCleaning
        }
        
        if ($DisableUpdates) {
            Disable-SteamUpdates
        }
        
        Remove-TempFiles
        
        Write-Log "Steam Optimization process completed successfully!" -Level Success
        Write-Log "Steam has been updated and configured for optimal performance." -Level Info
        Write-Log "You can contribute to improve the repository at: https://github.com/mtytyx/Steam-Debloat" -Level Info
        Write-Log "Press Enter to exit."
        if (-not $NoInteraction) {
            Read-Host
        }
    }
    catch {
        Write-Log "An error occurred during the Steam Optimization process: $_" -Level Error
        Write-Log "For more information and troubleshooting, please visit: $($script:config.ErrorPage)" -Level Info
        
        if (-not $NoInteraction -and (Read-Host "Do you want to restore Steam files from the latest backup? (Y/N)").ToUpper() -eq 'Y') {
            Restore-SteamFiles
        }
    }
}

# Main execution
if (-not $SkipIntro -and -not $NoInteraction) {
    Show-Introduction
}

$selectedMode = if ($Mode) { $Mode } else { Get-UserSelection }
Start-SteamDebloat -SelectedMode $selectedMode
