param (
    [string]$SelectedMode = "normal"
)
$STEAM_DIR = "C:\Program Files (x86)\Steam"

$MODES = @{
    "normal" = "-silent -no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -novid -noshaders -skipstreamingdrivers -norepairfiles"
    "lite" = "-silent -cef-force-32bit -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -novid -noshaders -skipstreamingdrivers -norepairfiles"
    "test" = "-silent -cef-force-32bit -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -novid -noshaders -skipstreamingdrivers -norepairfiles -nohltv -720p -cef-disable-gpu -cef-disable-extensions -cef-disable-remote-fonts -cef-disable-accelerated-video-decode"
}

function Create-SteamBatch {
    param (
        [string]$Mode
    )

    # Get temporary directory path
    $tempPath = [System.Environment]::GetEnvironmentVariable("TEMP")
    $batchPath = Join-Path $tempPath "Steam-$Mode.bat"

    # Create batch file content
    $batchContent = @"
@echo off
set STEAM_DIR="$STEAM_DIR"
set MODE_$($Mode.ToUpper())=$($MODES[$Mode.ToLower()])

"%STEAM_DIR%\Steam.exe" %MODE_$($Mode.ToUpper())%
"@

    # Write content to batch file
    try {
        $batchContent | Out-File -FilePath $batchPath -Encoding ASCII -Force
    }
    catch {
        Write-Error "Failed to create batch file: $_"
    }
}

# Create batch file based on selected mode
if ($MODES.ContainsKey($SelectedMode.ToLower())) {
    Create-SteamBatch -Mode $SelectedMode
}
else {
    Write-Error "Invalid mode selected. Available modes: Normal, Lite, Test"
}
