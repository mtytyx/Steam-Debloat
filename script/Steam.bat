@echo off
:: Steam Balanced Launcher
:: Optimized for low resource usage while maintaining most functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-silent -noverifyfiles -norepairfiles -noshaders -no-dwrite -nocrashdialog -single_core -tcp -clearbeta -netbuffer 262144 -cef-single-process -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning -cef-disable-remote-fonts -disable-gpu-vsync -threads 2"

start "" /B /NORMAL "%STEAM_PATH%" %OPTS%
exit
