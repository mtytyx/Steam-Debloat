# Enhanced Steam Debloat Script

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
    [string]$LogLevel = "Info",
    [switch]$ParallelProcessing,
    [switch]$CleanDuplicates,
    [switch]$OptimizeMemory,
    [switch]$GranularControl
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management

# Configuration
$script:config = @{
    Title = "Enhanced Steam Debloat"
    GitHub = "Github.com/mtytyx"
    Version = @{
        ps1 = "v7.0"
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
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
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

# Enhanced Logging Function with Log Rotation and Error Handling
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
    
    # Append to log file with rotation and error handling
    try {
        $logFile = $script:config.LogFile
        Add-Content -Path $logFile -Value $logMessage -ErrorAction Stop
        
        # Rotate log if it exceeds 10MB
        if ((Get-Item $logFile).Length -gt 10MB) {
            $backupLog = "$logFile.1"
            if (Test-Path $backupLog) {
                Remove-Item $backupLog -Force -ErrorAction Stop
            }
            Rename-Item $logFile $backupLog -ErrorAction Stop
            New-Item $logFile -ItemType File -ErrorAction Stop
        }
    }
    catch {
        Write-Host "Failed to write to log file: $_" -ForegroundColor Red
    }
    
    # If verbose mode is on, provide more details for debugging
    if ($VerbosePreference -eq 'Continue' -and $Level -eq "Debug") {
        $callStack = Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object { "$($_.FunctionName) - $($_.ScriptLineNumber)" }
        $debugInfo = "  Call Stack: $($callStack -join ' -> ')"
        Write-Host $debugInfo -ForegroundColor $script:config.Color.Debug
        try {
            Add-Content -Path $logFile -Value $debugInfo -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to write debug info to log file: $_" -ForegroundColor Red
        }
    }
}

# Progress Bar Function
function Show-Progress {
    param (
        [int]$PercentComplete,
        [string]$Status
    )
    Write-Progress -Activity "Steam Debloat Progress" -Status $Status -PercentComplete $PercentComplete
}

# Parallel File Processing Function
function Invoke-ParallelFileOperation {
    param (
        [scriptblock]$ScriptBlock,
        [string[]]$InputObject,
        [int]$ThrottleLimit = 5
    )
    
    $jobs = @()
    
    foreach ($item in $InputObject) {
        $jobs += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $item
        
        while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
            Start-Sleep -Milliseconds 100
        }
        
        foreach ($job in ($jobs | Where-Object { $_.State -eq 'Completed' })) {
            Receive-Job $job
            Remove-Job $job
        }
    }
    
    # Wait for remaining jobs
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
}

# Enhanced Backup Function with Progress Bar
function Backup-SteamFiles {
    Write-Log "Starting Steam backup process..." -Level Info
    $backupPath = Join-Path $script:config.BackupDir (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    
    try {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        
        $totalSize = (Get-ChildItem $script:config.SteamInstallDir -Recurse | Measure-Object -Property Length -Sum).Sum
        $copiedSize = 0
        
        # Use robocopy for efficient copying with progress reporting
        $robocopyArgs = @(
            $script:config.SteamInstallDir,
            $backupPath,
            "/E",
            "/Z",
            "/MT:16",
            "/R:3",
            "/W:10",
            "/BYTES",
            "/TEE",
            "/NP"
        )
        
        $robocopyJob = Start-Job -ScriptBlock {
            param($args)
            & robocopy.exe $args
        } -ArgumentList $robocopyArgs
        
        while ($robocopyJob.State -eq 'Running') {
            $output = Receive-Job $robocopyJob
            if ($output -match '(?<=\s+)\d+(?=\s+)') {
                $copiedSize = [long]$matches[0]
                $percentComplete = [math]::Min(100, [math]::Round(($copiedSize / $totalSize) * 100, 2))
                Show-Progress -PercentComplete $percentComplete -Status "Backing up Steam files..."
            }
            Start-Sleep -Milliseconds 500
        }
        
        $finalOutput = Receive-Job $robocopyJob
        Remove-Job $robocopyJob
        
        if ($finalOutput -notmatch 'ERROR') {
            Write-Log "Steam backup created successfully at $backupPath" -Level Success
        } else {
            throw "Robocopy encountered errors during backup. Check the log for details."
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

# Enhanced Cleaning Function
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
        
        # Clear Steam logs
        Remove-Item -Path "$($script:config.SteamInstallDir)\logs\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear Steam crash dumps
        Remove-Item -Path "$($script:config.SteamInstallDir)\dumps\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        # Clear Steam package cache
        Remove-Item -Path "$($script:config.SteamInstallDir)\package\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Log "Advanced cleaning completed successfully" -Level Success
    }
    catch {
        Write-Log "Error during advanced cleaning: $_" -Level Warning
    }
}

# Function to remove duplicate files
function Remove-DuplicateFiles {
    Write-Log "Searching for and removing duplicate files..." -Level Info
    
    try {
        $steamAppsPath = Join-Path $script:config.SteamInstallDir "steamapps\common"
        $files = Get-ChildItem -Path $steamAppsPath -Recurse -File
        
        $fileHashes = @{}
        $duplicatesRemoved = 0
        
        foreach ($file in $files) {
            $hash = Get-FileHash -Path $file.FullName -Algorithm MD5
            
            if ($fileHashes.ContainsKey($hash.Hash)) {
                Remove-Item -Path $file.FullName -Force
                $duplicatesRemoved++
            } else {
                $fileHashes[$hash.Hash] = $file.FullName
            }
        }
        
        Write-Log "Removed $duplicatesRemoved duplicate files" -Level Success
    }
    catch {
        Write-Log "Error while removing duplicate files: $_" -Level Warning
    }
}

# Function to optimize memory
function Optimize-SystemMemory {
    Write-Log "Optimizing system memory..." -Level Info
    
    try {
        # Clear standby list
        Write-Log "Clearing standby list..." -Level Info
        $standbyListCleaner = @"
using System;
using System.Runtime.InteropServices;

public static class MemoryOptimizer
{
    [DllImport("psapi.dll")]
    static extern int EmptyWorkingSet(IntPtr hwProc);

    public static void ClearStandbyList()
    {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        EmptyWorkingSet(System.Diagnostics.Process.GetCurrentProcess().Handle);
    }
}
"@

        Add-Type -TypeDefinition $standbyListCleaner

        [MemoryOptimizer]::ClearStandbyList()
        
        # Adjust virtual memory
        Write-Log "Adjusting virtual memory settings..." -Level Info
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $totalRam = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB)
        
        $initialSize = $totalRam * 1024
        $maximumSize = $initialSize * 3
        
        $pagefile = Get-WmiObject -Class Win32_PageFileSetting
        $pagefile.InitialSize = $initialSize
        $pagefile.MaximumSize = $maximumSize
        $pagefile.Put()
        
        Write-Log "Memory optimization completed" -Level Success
    }
    catch {
        Write-Log "Error during memory optimization: $_" -Level Warning
    }
}

# Function for granular control of Steam services
function Set-SteamServices {
    param (
        [switch]$DisableUpdates,
        [switch]$DisableBroadcasting,
        [switch]$DisableWorkshop,
        [switch]$DisableCloudSync
    )
    
    Write-Log "Configuring Steam services..." -Level Info
    
    try {
        $steamConfigPath = Join-Path $script:config.SteamInstallDir "config\config.vdf"
        $config = Get-Content $steamConfigPath -Raw
        
        if ($DisableUpdates) {
            $config = $config -replace '"AutoUpdateEnabled"\s+"1"', '"AutoUpdateEnabled"		"0"'
            Write-Log "Disabled automatic updates" -Level Info
        }
        
        if ($DisableBroadcasting) {
            $config = $config -replace '"EnableBroadcasts"\s+"1"', '"EnableBroadcasts"		"0"'
            Write-Log "Disabled broadcasting" -Level Info
        }
        
        if ($DisableWorkshop) {
            $config = $config -replace '"EnableWorkshop"\s+"1"', '"EnableWorkshop"		"0"'
            Write-Log "Disabled Workshop" -Level Info
        }
        
        if ($DisableCloudSync) {
            $config = $config -replace '"EnableCloudSync"\s+"1"', '"EnableCloudSync"		"0"'
            Write-Log "Disabled Cloud Sync" -Level Info
        }
        
        $config | Set-Content $steamConfigPath -Force
        Write-Log "Steam services configured successfully" -Level Success
    }
    catch {
        Write-Log "Error configuring Steam services: $_" -Level Warning
    }
}

# Function to remove unused language packs
function Remove-UnusedLanguagePacks {
    Write-Log "Removing unused language packs..." -Level Info
    
    try {
        $languageFolder = Join-Path $script:config.SteamInstallDir "steam\games\*\*_*.vpk"
        $currentLanguage = (Get-Culture).Name
        
        Get-ChildItem -Path $languageFolder -Recurse | Where-Object {
            $_.Name -notmatch $currentLanguage
        } | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Log "Removed language pack: $($_.Name)" -Level Info
        }
        
        Write-Log "Unused language packs removed successfully" -Level Success
    }
    catch {
        Write-Log "Error removing unused language packs: $_" -Level Warning
    }
}

# Main execution function
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
        
        $downgradeChoice = Get-DowngradeChoice
        if ($downgradeChoice) {
            $customUrl = Get-CustomVersionUrl
            $downgradeUrl = if ($customUrl) { $customUrl } else { $script:config.DefaultDowngradeUrl }
            Invoke-SteamUpdate -Url $downgradeUrl
        } else {
            Write-Log "Skipping Steam downgrade process." -Level Info
        }
        
        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode
        
        if ($PerformanceMode) {
            Optimize-SteamPerformance
        }
        
        if ($AdvancedCleaning) {
            Invoke-AdvancedCleaning
        }
        
        if ($CleanDuplicates) {
            Remove-DuplicateFiles
        }
        
        if ($OptimizeMemory) {
            Optimize-SystemMemory
        }
        
        if ($GranularControl) {
            Set-SteamServices -DisableUpdates:$DisableUpdates -DisableBroadcasting -DisableWorkshop -DisableCloudSync
        }
        
        Remove-UnusedLanguagePacks
        
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
