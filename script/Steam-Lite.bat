@echo off
:: Steam Lite Launcher
:: Optimized for lower resource usage while maintaining essential functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -netbuffer 262144 -cef-single-process -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning -cef-force-32bit -disable-gpu-vsync -console"

start "" /B /LOW "%STEAM_PATH%" %OPTS%
exit
