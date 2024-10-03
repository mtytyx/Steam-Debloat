@echo off
:: Steam Lite Launcher (Test Mode)
:: Designed for absolute minimal resource usage and extensive testing

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -netbuffer 65536 -cef-single-process -no-cef-sandbox -vrdisable -no-browser -disable-gpu-vsync -disable-gpu -cef-force-32bit -no-shared-textures -disable-font-subpixel-positioning -disable-smooth-scrolling -threads 1 -offline -silent -console"

start "" /B /LOW "%STEAM_PATH%" %OPTS%
exit
