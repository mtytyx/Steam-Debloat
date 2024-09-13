[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ValidateSet("Normal", "Lite", "TEST", "TEST-Lite", "TEST-Version")]
    [string]$Mode = $null,

    [switch]$SkipIntro,
    [switch]$ForceBackup,
    [switch]$SkipDowngrade,
    [string]$CustomVersion,
    [switch]$NoInteraction
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management

# Configuration
$script:config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx/Steam-Debloat"
    Version = @{
        ps1 = "v3.4"  # Updated version number
        Stable = "v2.3"
        Beta = "v1.3"
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
    LogFile = Join-Path $env:USERPROFILE "Desktop\SteamDebloat.log"
    BackupDir = Join-Path $env:USERPROFILE "SteamDebloatBackup"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    MaxBackups = 5
    RetryAttempts = 3
    RetryDelay = 5
}

# Enhanced Logging Function
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
    
    # Append to log file
    Add-Content -Path $script:config.LogFile -Value $logMessage
    
    # If verbose mode is on, provide more details for debugging
    if ($VerbosePreference -eq 'Continue' -and $Level -eq "Debug") {
        $callStack = Get-PSCallStack | Select-Object -Skip 1 | ForEach-Object { "$($_.FunctionName) - $($_.ScriptLineNumber)" }
        $debugInfo = "  Call Stack: $($callStack -join ' -> ')"
        Write-Host $debugInfo -ForegroundColor $script:config.Color.Debug
        Add-Content -Path $script:config.LogFile -Value $debugInfo
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
    Write-Log "`nWelcome to $($script:config.Title) - $($script:config.GitHub) - $($script:config.Version.ps1) `n" -Level Info
    Write-Log "This script optimizes and debloats Steam for better performance." -Level Info
    Write-Log "------------------------------------------------" -Level Info
    Write-Log "1. Steam Debloat Stable (Version $($script:config.Version.Stable))" -Level Info
    Write-Log "2. Steam Debloat Beta (Version $($script:config.Version.Beta))" -Level Info
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
        if ($VerbosePreference -eq 'Continue') { $arguments += " -Verbose" }
        
        Start-ProcessAsAdmin -FilePath "powershell.exe" -ArgumentList $arguments
        exit
    }
}

function Stop-SteamProcesses {
    Write-Log "Stopping Steam processes..." -Level Info
    Get-Process | Where-Object { $_.Name -like "*steam*" } | ForEach-Object {
        try {
            $_.Kill()
            $_.WaitForExit(5000)
            Write-Log "Stopped process: $($_.Name)" -Level Debug
        }
        catch {
            Write-Log "Failed to stop process $($_.Name): $_" -Level Warning
        }
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

function Invoke-SteamUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url
    )
    
    Write-Log "Starting Steam update process..." -Level Info
    $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"
    Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments
    
    Write-Log "Waiting for Steam to close..." -Level Info
    $timeout = 300 # 5 minutes timeout
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
        if ($timer.Elapsed.TotalSeconds -gt $timeout) {
            Write-Log "Timeout reached. Steam process did not close." -Level Warning
            break
        }
        Start-Sleep -Seconds 5
    }
    $timer.Stop()
}

function Get-DowngradeChoice {
    if ($NoInteraction) {
        return -not $SkipDowngrade
    }
    $choice = Read-Host "Do you want to downgrade Steam? (Y/N)"
    return $choice.ToUpper() -eq 'Y'
}

function Get-CustomVersionUrl {
    if ($NoInteraction) {
        return $CustomVersion
    }
    $useCustom = Read-Host "Do you want to use a custom version URL? (Y/N)"
    if ($useCustom.ToUpper() -eq 'Y') {
        return Read-Host "Enter the custom version URL"
    }
    return $null
}

function Backup-SteamFiles {
    Write-Log "Starting Steam backup process..." -Level Info
    $backupPath = Join-Path $script:config.BackupDir (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
    
    try {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        Copy-Item -Path $script:config.SteamInstallDir -Destination $backupPath -Recurse -Force
        Write-Log "Steam backup created successfully at $backupPath" -Level Success
        
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
        Remove-Item -Path $script:config.SteamInstallDir -Recurse -Force
        Copy-Item -Path $latestBackup.FullName -Destination $script:config.SteamInstallDir -Recurse
        Write-Log "Steam files restored successfully from $($latestBackup.FullName)" -Level Success
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
        
        Remove-TempFiles
        
        Write-Log "Steam Debloat process completed successfully!" -Level Success
        Write-Log "Please run the Steam-$SelectedMode.bat file on your desktop to complete the optimization." -Level Info
    }
    catch {
        Write-Log "An error occurred during the Steam Debloat process: $_" -Level Error
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
