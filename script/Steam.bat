@echo off
:: Steam Balanced Launcher (Normal Mode)
:: Optimized for good performance while maintaining normal functionality

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

:: Options balanced for performance and functionality
set "OPTS=-noverifyfiles -norepairfiles -noshaders -nocrashdialog -tcp -clearbeta -netbuffer 524288 -no-cef-sandbox -vrdisable -no-shared-textures -disable-font-subpixel-positioning -threads 4 -console"

start "" /B /NORMAL "%STEAM_PATH%" %OPTS%
exit
