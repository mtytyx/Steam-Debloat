@echo off
:: Steam Ultra-Lite Launcher
:: Designed for absolute minimal resource usage

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

set "OPTS=-nobootstrapupdate -nobigpicture -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -netbuffer 131072 -cef-single-process -no-cef-sandbox -vrdisable"

start "" /B /LOW "%STEAM_PATH%" %OPTS%
exit
