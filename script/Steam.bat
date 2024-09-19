@echo off
:: Steam Balanced Launcher
:: Optimized for low resource usage while maintaining most functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

:: Options adjusted to enable minimal GPU acceleration and resolve black library screen issue
set "OPTS=-silent -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -netbuffer 262144 -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning -threads 2"

start "" /B /NORMAL "%STEAM_PATH%" %OPTS%
exit
