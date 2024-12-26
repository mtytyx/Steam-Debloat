
# Configuration
$script:config = @{
    Title               = "Steam Debloat"
    GitHub              = "Github.com/mtytyx/Steam-Debloat"
    Version             = "v1.0.052"
    Color               = @{Info = "Cyan"; Success = "Magenta"; Warning = "DarkYellow"; Error = "DarkRed"; Debug = "Blue" }
    ErrorPage           = "https://github.com/mtytyx/Steam-Debloat/issues"
    Urls                = @{
        "SteamSetup"       = "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"
        "MaintenanceCheck" = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/maintenanceapp.json"
        "SteamScript"      = "https://raw.githubusercontent.com/mtytyx/Steam-Debloat/refs/heads/main/script/steam.ps1"
    }
    DefaultDowngradeUrl = "https://archive.org/download/dec2022steam"
    SteamInstallDir     = "C:\Program Files (x86)\Steam"
    RetryAttempts       = 3
    RetryDelay          = 5
    LogFile             = Join-Path $env:TEMP "Steam-Debloat.log"
    SteamScriptPath     = Join-Path $env:TEMP "steam.ps1"
}

# Download steam.ps1 script
function Get-SteamScript {
    try {
        Invoke-SafeWebRequest -Uri $script:config.Urls.SteamScript -OutFile $script:config.SteamScriptPath
        return $true
    }
    catch {
        return $false
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

    # Call steam.ps1 to generate the batch file
    $steamBatPath = Join-Path $env:TEMP "Steam-$SelectedMode.bat"
    & $script:config.SteamScriptPath -SelectedMode $SelectedMode

    # Create basic steam.cfg content
    $steamCfgPath = Join-Path $env:TEMP "steam.cfg"
    @"
BootStrapperInhibitAll=enable
BootStrapperForceSelfUpdate=disable
"@ | Out-File -FilePath $steamCfgPath -Encoding ASCII -Force

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

        if (-not $NoInteraction -and (Read-Host "Do you want to downgrade Steam? (Y/N) (Press N method obsolote)").ToUpper() -eq 'Y') {
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
# Download steam.ps1 at startup
if (-not (Get-SteamScript)) {
    Write-DebugLog "Cannot proceed without steam.ps1 script." -Level Error
    exit
}
