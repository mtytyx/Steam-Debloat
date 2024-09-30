# Steam-Lite.bat
@echo off
:: Steam Lite Launcher
:: Balanced approach for low resource usage while maintaining basic functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -netbuffer 131072 -cef-single-process -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning"

start "" /B /LOW "%STEAM_PATH%" %OPTS%
exit
