param (
    [string]$SelectedMode = "normal"
)

$STEAM_DIR = "C:\Program Files (x86)\Steam"
$MODES = @{
    "normal" = "-no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    "lite" = "-silent -cef-force-32bit -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-gpu-compositing -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    "test" = "-cef-force-32bit -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
}

function Create-SteamBatch {
    param (
        [string]$Mode
    )
    # Get temporary directory path
    $tempPath = [System.Environment]::GetEnvironmentVariable("TEMP")
    $batchPath = Join-Path $tempPath "Steam-$Mode.bat"

    # Create batch file content with the new format
    $batchContent = @"
@echo off
cd /d "C:\Program Files (x86)\Steam"
start Steam.exe $($MODES[$Mode.ToLower()])
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
