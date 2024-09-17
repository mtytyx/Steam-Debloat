@echo off
:: Steam Lite Launcher
:: Balanced approach for low resource usage while maintaining basic functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-silent -nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -no-dwrite -disable-gpu -nocrashdialog -single_core -tcp -clearbeta -netbuffer 131072 -cef-single-process -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning -cef-disable-remote-fonts"

start "" /B /LOW "%STEAM_PATH%" %OPTS%
exit
