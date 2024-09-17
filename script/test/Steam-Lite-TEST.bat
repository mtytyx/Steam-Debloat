@echo off
:: Steam Ultra-Lite Launcher
:: Designed for absolute minimal resource usage

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-silent -no-browser -nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -no-dwrite -disable-gpu -disable-d3d9ex -nocrashdialog -nofriendsui -single_core -tcp -clearbeta -netbuffer 131072 -cef-single-process -cef-in-process-gpu -no-cef-sandbox -disable-winh264 -cef-disable-d3d11 -vrdisable"

start "" /B /LOW /REALTIME "%STEAM_PATH%" %OPTS%
exit
