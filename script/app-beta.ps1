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

# Strict mode configuration for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration settings
$script:config = @{
    Title = "Steam Debloat"
    GitHub = "Github.com/mtytyx/Steam-Debloat"
    Version = "v7.6"
    Color = @{Info = "Cyan"; Success = "Green"; Warning = "Yellow"; Error = "Red"; Debug = "Magenta"}
    ErrorPage = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls = @{
        "Normal" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam.bat"
        "Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/Steam-Lite.bat"
        "TEST" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "TEST-Lite" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-Lite-TEST.bat"
        "TEST-Version" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/test/Steam-TEST.bat"
        "SteamCfg" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/steam.cfg"
        "MaintenanceStatus" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/maintenance.json" # URL para verificar mantenimiento
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    LogFile = Join-Path $env:USERPROFILE "Desktop\Steam-Debloat.log"
    SteamInstallDir = "C:\Program Files (x86)\Steam"
    RetryAttempts = 3
    RetryDelay = 5
}

function Test-MaintenanceStatus {
    try {
        # Verificación silenciosa
        $response = Invoke-WebRequest -Uri $script:config.Urls.MaintenanceStatus -UseBasicParsing
        $maintenance = $response.Content | ConvertFrom-Json
        
        if ($maintenance.status -eq "on") {
            # Solo mostrar mensajes si hay mantenimiento
            Write-Host "`n===============================`n" -ForegroundColor Red
            Write-Host "SCRIPT IN MANTENANCE" -ForegroundColor Red
            Write-Host "Reason: $($maintenance.reason)" -ForegroundColor Red
            Write-Host "`nEstimated time 5-10 minutes" -ForegroundColor Red
            Write-Host "`n===============================`n" -ForegroundColor Red
            
            # Registrar en el log pero sin mostrar en pantalla
            Write-Log "script in maintenance - $($maintenance.reason)" -Level Warning
            
            if (-not $NoInteraction) { 
                Read-Host "nPress Enter to exit" 
            }
            exit
        }
        return $true
    }
    catch {
        return $true
    }
}

# Logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoNewline
    )
    
    # Get current timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Set color based on log level
    $color = $script:config.Color[$Level]
    
    # Write to console and log file
    if ($NoNewline) {
        Write-Host -NoNewline "[$Level] $Message" -ForegroundColor $color
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
    
    # Append message to log file
    Add-Content -Path $script:config.LogFile -Value $logMessage
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
            # Attempt to download the file from the provided URL
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return  # Exit if download is successful
        } catch {
            # Handle errors if download fails
            if ($attempt -ge $script:config.RetryAttempts) {
                throw "Failed to download from $Uri after $($script:config.RetryAttempts) attempts: $_"
            }
            Write-Log "Download attempt $attempt failed. Retrying in $($script:config.RetryDelay) seconds..." -Level Warning
            Start-Sleep -Seconds $script:config.RetryDelay  # Wait before retrying
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
    
    Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Verb RunAs -Wait  # Run the process with elevated privileges
}

# Stop running Steam processes
function Stop-SteamProcesses {
    Get-Process | Where-Object { $_.Name -like "*steam*" } | ForEach-Object {
        try {
            $_.Kill()  # Kill the Steam process
            $_.WaitForExit(5000)  # Wait until the process has exited or timeout occurs
            Write-Log "Stopped process: $($_.Name)" -Level Info  # Log the stopping of the process
        } catch {
            Write-Log "Failed to stop process $($_.Name): $_" -Level Warning  # Handle errors when stopping processes
        }
    }
}

# Get required files based on selected mode
function Get-RequiredFiles {
    param (
        [string]$SelectedMode
    )
    
    # Temporary paths for files to download
    $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
    $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
    
    Write-Log "Downloading Steam-$SelectedMode.bat..." -Level Info  # Log download of BAT script
    Invoke-SafeWebRequest -Uri $script:config.Urls[$SelectedMode] -OutFile $steamBatPath  # Download BAT file
    
    Write-Log "Downloading steam.cfg..." -Level Info  # Log download of CFG file
    Invoke-SafeWebRequest -Uri $script:config.Urls.SteamCfg -OutFile $steamCfgPath  # Download CFG file
    
    return @{ SteamBat = $steamBatPath; SteamCfg = $steamCfgPath }  # Return paths of downloaded files
}

# Invoke Steam update with provided URL
function Invoke-SteamUpdate {
    param (
        [string]$Url
    )
    
   # Arguments for Steam update command 
   $arguments = "-forcesteamupdate -forcepackagedownload -overridepackageurl $Url -exitsteam"

   Write-Log "Updating Steam from $Url..." -Level Info  # Log start of update
   
   Start-Process -FilePath "$($script:config.SteamInstallDir)\steam.exe" -ArgumentList $arguments  # Start the update
   
   # Wait until the Steam process is finished or timeout occurs (300 seconds)
   $timeout = 300 
   $timer = [Diagnostics.Stopwatch]::StartNew()
   
   while (Get-Process -Name "steam" -ErrorAction SilentlyContinue) {
       if ($timer.Elapsed.TotalSeconds -gt $timeout) {
           Write-Log "Steam update process timed out after $timeout seconds." -Level Warning  # Log if timeout occurs 
           break 
       }
       Start-Sleep -Seconds 5  # Wait before checking again if Steam is still running 
   }
   
   $timer.Stop()
   
   Write-Log "Steam update process completed in $($timer.Elapsed.TotalSeconds) seconds." -Level Info  # Log total time for update 
}

# Move configuration file to Steam installation folder 
function Move-ConfigFile {
   param (
       [string]$SourcePath 
   )
   
   # Define destination path for CFG file 
   $destinationPath = Join-Path $script:config.SteamInstallDir "steam.cfg" 
   Copy-Item -Path $SourcePath -Destination $destinationPath -Force  # Copy CFG file to final location 
   Write-Log "Moved steam.cfg to $destinationPath" -Level Info  # Log movement of file 
}

# Move BAT file to user's desktop 
function Move-SteamBatToDesktop {
   param (
       [string]$SourcePath,
       [string]$SelectedMode 
   )
   
   # Define destination path for BAT file on desktop 
   $destinationPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Steam-$SelectedMode.bat" 
   Copy-Item -Path $SourcePath -Destination $destinationPath -Force  # Copy BAT file to desktop 
   Write-Log "Moved Steam-$SelectedMode.bat to desktop" -Level Info  # Log movement of file 
}

# Remove temporary files after process completion 
function Remove-TempFiles {
   Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue  # Remove temporary BAT files 
   Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue  # Remove temporary CFG file 
   Write-Log "Removed temporary files" -Level Info  # Log removal of temporary files 
}

# Main function to start the optimization process for Steam 
function Start-SteamDebloat {
    param (
        [string]$SelectedMode
    )
    
    try {
        # Verificar mantenimiento antes de continuar
        if (-not (Test-MaintenanceStatus)) {
            return
        }

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

        # Resto del código original de Start-SteamDebloat...
        $host.UI.RawUI.WindowTitle = "$($script:config.Title) - $($script:config.GitHub)"
        Write-Log "`nStarting optimization in mode: '$SelectedMode'" -Level Info

        Stop-SteamProcesses
        $files = Get-RequiredFiles -SelectedMode $SelectedMode

        if ($SelectedMode -eq "TEST-Version") {
            if (-not $CustomVersion) {
                $CustomVersion = Read-Host "`nEnter the custom version URL for Steam update:"
            }
            if ($CustomVersion) {
                Invoke-SteamUpdate -Url $CustomVersion
            }
            else {
                Write-Log "`nNo custom version URL provided. Skipping Steam update." -Level Warning
            }
        }
        elseif (-not $NoInteraction -and (Read-Host "`nDo you want to downgrade Steam? (Y/N)").ToUpper() -eq 'Y') {
            Invoke-SteamUpdate -Url $script:config.DefaultDowngradeUrl
        }

        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat -SelectedMode $SelectedMode

        Remove-TempFiles

        Write-Log "`nOptimization process completed successfully!" -Level Success
        Write-Log "`nSteam has been updated and configured for optimal performance." -Level Info
        Write-Log "`nYou can contribute to improve the repository at: `"$($script:config.GitHub)`"" -Level Info

        if (-not $NoInteraction) { Read-Host "`nPress Enter to exit" }
    }
    catch {
        Write-Log "`nAn error occurred: $_" -Level Error
        Write-Log "`nFor troubleshooting, visit: `"$($script:config.ErrorPage)`"" -Level Info
    }
}


# Main execution of the script 
if (-not $SkipIntro -and -not $NoInteraction) {     Clear-host     Write-host @"

 ____ _                        ____ _     _             _   
 / ___| |_ ___ __ _ _ __ ___ | __ ) | __| |_ __ _ _ __| |_ 
 \___ \ __/ _ \ _` | '_ ` _ \ | | | | '__| __| '_ \| '__| __|
 ___) | || __/ (_| | | | | | || |_| | | | |_| |_) | | | |_| 
|____/ \__\___|\__,_|_| |_| |_|____/|_| |_|\__| .__/|_| |_|\__|
                                                |_|                
"@ –ForegroundColor Cyan     Write-log "`nWelcome to `"$($script:config.Title)`" – `$($script:config.GitHub)`" – `$($script:config.Version)`n" –Level Info     $Mode=Read-host "`nChoose mode (Normal/Lite/TEST/TEST-Lite/TEST-Version)" }

Start-SteamDebloat –SelectedMode $Mode    # Start main process with selected mode
