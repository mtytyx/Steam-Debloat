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
# Try this function if the script gives you an error
# This generates a log in %temp%
$Debug = "off"

# Configuration
$script:config = @{
    Title               = "Steam Debloat"
    GitHub              = "Github.com/mtytyx/Steam-Debloat"
    Version            = "v1.0.091"
    Color              = @{Info = "Cyan"; Success = "Magenta"; Warning = "DarkYellow"; Error = "DarkRed"; Debug = "Blue" }
    ErrorPage          = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls               = @{
        "SteamSetup"       = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
        "MaintenanceCheck" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/maintenanceapp.json"
        "SteamScript"      = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/refs/heads/main/script/steam.ps1"
    }
    SteamInstallDir    = "C:\Program Files (x86)\Steam"
    RetryAttempts      = 3
    RetryDelay         = 5
    LogFile            = Join-Path $env:TEMP "Steam-Debloat.log"
    SteamScriptPath    = Join-Path $env:TEMP "steam.ps1"
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
 ______     ______   ______     ______     __    __                                                                                    
/\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ "-./  \                                                                                   
\ \___  \  \/_/\ \/ \ \  __\   \ \  __ \  \ \ \-./\ \                                                                                  
 \/\_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_\ \ \_\                                                                                 
  \/_____/     \/_/   \/_____/   \/_/\/_/   \/_/  \/_/                                                                                 
                                                                                                                                       
                __    __     ______     __     __   __     ______   ______     __   __     ______     __   __     ______     ______    
               /\ "-./  \   /\  __ \   /\ \   /\ "-.\ \   /\__  _\ /\  ___\   /\ "-.\ \   /\  __ \   /\ "-.\ \   /\  ___\   /\  ___\   
               \ \ \-./\ \  \ \  __ \  \ \ \  \ \ \-.  \  \/_/\ \/ \ \  __\   \ \ \-.  \  \ \  __ \  \ \ \-.  \  \ \ \____  \ \  __\   
                \ \_\ \ \_\  \ \_\ \_\  \ \_\  \ \_\\"\_\    \ \_\  \ \_____\  \ \_\\"\_\  \ \_\ \_\  \ \_\\"\_\  \ \_____\  \ \_____\ 
                 \/_/  \/_/   \/_/\/_/   \/_/   \/_/ \/_/     \/_/   \/_____/   \/_/ \/_/   \/_/\/_/   \/_/ \/_/   \/_____/   \/_____/ 
                                                                                                                                       
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

# Download steam.ps1 script
function Get-SteamScript {
    $maxAttempts = 3
    $attempt = 0
    do {
        $attempt++
        try {
            Invoke-SafeWebRequest -Uri $script:config.Urls.SteamScript -OutFile $script:config.SteamScriptPath
            if (Test-Path $script:config.SteamScriptPath) {
                $content = Get-Content $script:config.SteamScriptPath -Raw
                if ($content) { return $true }
            }
        } catch {
            Write-DebugLog "Attempt $attempt to download steam.ps1 failed: $_" -Level Warning
            if ($attempt -ge $maxAttempts) { return $false }
            Start-Sleep -Seconds 2
        }
    } while ($attempt -lt $maxAttempts)
    return $false
}

# Function to wait for path existence
function Wait-ForPath {
    param(
        [string]$Path,
        [int]$TimeoutSeconds = 300
    )
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path $Path)) {
        if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            Write-DebugLog "Timeout waiting for: $Path" -Level Error
            return $false
        }
        Start-Sleep -Seconds 1
    }
    return $true
}

# Steam Installation function
function Install-SteamApplication {
    Write-DebugLog "Starting Steam installation process..." -Level Info
    $setupPath = Join-Path $env:TEMP "SteamSetup.exe"

    try {
        Write-DebugLog "Downloading Steam installer..." -Level Info
        Invoke-SafeWebRequest -Uri $script:config.Urls.SteamSetup -OutFile $setupPath
        
        Write-DebugLog "Running Steam installer..." -Level Info
        Start-Process -FilePath $setupPath -ArgumentList "/S" -Wait

        Write-DebugLog "Waiting for installation to complete..." -Level Info
        if (-not (Wait-ForPath -Path $script:config.SteamInstallDir -TimeoutSeconds 300)) {
            Write-DebugLog "Steam installation did not complete in the expected time" -Level Error
            return $false
        }

        $steamExePath = Join-Path $script:config.SteamInstallDir "steam.exe"
        if (Test-Path $steamExePath) {
            Write-DebugLog "Steam installed successfully!" -Level Success
            Remove-Item $setupPath -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-DebugLog "Steam installation failed - steam.exe not found" -Level Error
            return $false
        }
    }
    catch {
        Write-DebugLog "Failed to install Steam: $_" -Level Error
        return $false
    }
}

# Main Steam function
function Install-Steam {
    try {
        $steamExePath = Join-Path $script:config.SteamInstallDir "steam.exe"
        $needsInstallation = -not (Test-Path $steamExePath)

        if ($needsInstallation) {
            $installSuccess = Install-SteamApplication
            if (-not $installSuccess) {
                return $false
            }
        }

        $startSuccess = Start-SteamWithParameters -Mode $Mode
        if (-not $startSuccess) {
            return $false
        }

        return $true
    }
    catch {
        Write-DebugLog "An error occurred in Install-Steam: $_" -Level Error
        return $false
    }
}

# Start Steam with parameters
function Start-SteamWithParameters {
    param (
        [string]$Mode
    )
    
    try {
        $steamExePath = Join-Path $script:config.SteamInstallDir "steam.exe"
        if (-not (Test-Path $steamExePath)) {
            Write-DebugLog "Steam executable not found at: $steamExePath" -Level Error
            return $false
        }

        $arguments = if ($Mode -in "Lite", "TEST") {
            "-forcesteamupdate -forcepackagedownload -overridepackageurl https://archive.org/download/dec2022steam -exitsteam"
        }
        else {
            "-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
        }

        Start-Process -FilePath $steamExePath -ArgumentList $arguments

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
        
        return $true
    }
    catch {
        Write-DebugLog "Failed to start Steam: $_" -Level Error
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

    Write-DebugLog "Generating Steam batch file for $SelectedMode mode..." -Level Info

    $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
    & $script:config.SteamScriptPath -SelectedMode $SelectedMode

    $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
    @"
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
"@ | Out-File -FilePath $steamCfgPath -Encoding ASCII -Force

    return @{ SteamBat = $steamBatPath; SteamCfg = $steamCfgPath }
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

# Move Steam bat to desktop
function Move-SteamBatToDesktop {
    param (
        [string]$SourcePath
    )
    $destinationPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "steam.bat"
    Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    Write-DebugLog "Moved steam.bat to desktop" -Level Info

    if (-not $NoInteraction) {
        $startupChoice = Read-Host "Do you want to start your PC with optimized Steam? (Y/N)"
        if ($startupChoice.ToUpper() -eq 'Y') {
            Move-SteamBatToStartup -SourcePath $destinationPath
        }
    }
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

# Remove temporary files
function Remove-TempFiles {
    Remove-Item -Path (Join-Path $env:TEMP "Steam-*.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "steam.cfg") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $env:TEMP "steam.ps1") -Force -ErrorAction SilentlyContinue
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

        Write-DebugLog "Starting $($script:config.Title) Optimization in $SelectedMode mode" -Level Info
        
        # Execute Start-SteamWithParameters immediately after the optimization message
        Write-DebugLog "Initializing Steam with optimized parameters..." -Level Info
        $steamResult = Start-SteamWithParameters -Mode $SelectedMode
        if (-not $steamResult) {
            Write-DebugLog "Failed to start Steam with optimized parameters" -Level Warning
        }

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
        Move-ConfigFile -SourcePath $files.SteamCfg
        Move-SteamBatToDesktop -SourcePath $files.SteamBat
        Remove-TempFiles

        Write-DebugLog "Steam Optimization process completed successfully!" -Level Success
        Write-DebugLog "Steam has been updated and configured for optimal performance." -Level Success
        Write-DebugLog "You can contribute to improve the repository at: $($script:config.GitHub)" -Level Success
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
$host.UI.RawUI.WindowTitle = "$($script:config.GitHub)"

# Download steam.ps1 at startup
if (-not (Get-SteamScript)) {
    Write-DebugLog "Cannot proceed without steam.ps1 script." -Level Error
    exit
}

if (-not $SkipIntro -and -not $NoInteraction) {
    Clear-Host
    Write-Host @"
 ______     ______   ______     ______     __    __           
/\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ "-./  \          
\ \___  \  \/_/\ \/ \ \  __\   \ \  __ \  \ \ \-./\ \         
 \/\_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_\ \ \_\        
  \/_____/     \/_/   \/_____/   \/_/\/_/   \/_/  \/_/        
                                                              
                __    __     ______     __   __     __  __    
               /\ "-./  \   /\  ___\   /\ "-.\ \   /\ \/\ \   
               \ \ \-./\ \  \ \  __\   \ \ \-.  \  \ \ \_\ \  
                \ \_\ \ \_\  \ \_____\  \ \_\\"\_\  \ \_____\ 
                 \/_/  \/_/   \/_____/   \/_/ \/_/   \/_____/ 
                                                              
"@ -ForegroundColor Cyan
    Write-DebugLog "$($script:config.Version)" -Level Info
    $Mode = Read-Host "Choose mode (Normal/Lite/TEST)"
}

Start-SteamDebloat -SelectedMode $Mode
