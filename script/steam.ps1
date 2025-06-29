param (
    [string]$SelectedMode = "Normal2025July"
)

$STEAM_DIR = "C:\Program Files (x86)\Steam"
$STEAM_DIR_V2 = "C:\Program Files (x86)\Steamv2"

$MODES = @{
    "normal2025july" = "-no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    "normal2022dec" = "-no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    "lite2022dec" = "-silent -cef-force-32bit -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-gpu-compositing -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    "normalboth2022-2025" = @{
        "steam2025" = "-no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
        "steam2022" = "-no-dwrite -no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -disablehighdpi -cef-single-process -cef-in-process-gpu -single_core -cef-disable-d3d11 -cef-disable-sandbox -disable-winh264 -vrdisable -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    }
}

function Create-SteamBatch {
    param (
        [string]$Mode
    )

    $tempPath = [System.Environment]::GetEnvironmentVariable("TEMP")
    $modeKey = $Mode.ToLower()
    
    try {
        if ($modeKey -eq "normalboth2022-2025") {
            $batchPath2025 = Join-Path $tempPath "Steam2025.bat"
            $batchContent2025 = @"
@echo off
echo Launching Steam 2025 (Latest) with optimized parameters...
cd /d "$STEAM_DIR"
start Steam.exe $($MODES[$modeKey]["steam2025"])
"@
            $batchContent2025 | Out-File -FilePath $batchPath2025 -Encoding ASCII -Force
            
            $batchPath2022 = Join-Path $tempPath "Steam2022.bat"
            $batchContent2022 = @"
@echo off
echo Launching Steam 2022 (December 2022) with optimized parameters...
cd /d "$STEAM_DIR_V2"
start Steam.exe $($MODES[$modeKey]["steam2022"])
"@
            $batchContent2022 | Out-File -FilePath $batchPath2022 -Encoding ASCII -Force
        } else {
            $batchPath = Join-Path $tempPath "Steam-$Mode.bat"
            $steamDir = if ($modeKey -eq "normal2022dec" -or $modeKey -eq "lite2022dec") { $STEAM_DIR } else { $STEAM_DIR }
            
            $batchContent = @"
@echo off
echo Launching Steam with optimized parameters...
cd /d "$steamDir"
start Steam.exe $($MODES[$modeKey])
"@
            $batchContent | Out-File -FilePath $batchPath -Encoding ASCII -Force
        }
    }
    catch {
        Write-Error "Failed to create batch file: $_"
    }
}

if ($MODES.ContainsKey($SelectedMode.ToLower())) {
    Create-SteamBatch -Mode $SelectedMode
} else {
    Write-Error "Invalid mode selected: $SelectedMode"
    Write-Host "Available modes:" -ForegroundColor Yellow
    Write-Host "- Normal2025July (Latest Steam version)" -ForegroundColor White
    Write-Host "- Normal2022dec (December 2022 Steam version)" -ForegroundColor White  
    Write-Host "- Lite2022dec (Lite December 2022 version)" -ForegroundColor White
    Write-Host "- NormalBoth2022-2025 (Experimental - Both versions)" -ForegroundColor White
}
