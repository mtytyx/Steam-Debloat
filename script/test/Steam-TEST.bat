@echo off
setlocal enabledelayedexpansion

:: Steam Test Launcher
:: Configurable options for testing different optimization levels

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

:: Base options
set "BASE_OPTS=-silent -noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta"

:: Toggleable options (0 = off, 1 = on)
set "DISABLE_BROWSER=0"
set "DISABLE_GPU=0"
set "USE_CEF_SINGLE_PROCESS=1"
set "DISABLE_VR=1"
set "LIMIT_THREADS=1"

:: Build options string
set "OPTS=!BASE_OPTS!"
if %DISABLE_BROWSER%==1 set "OPTS=!OPTS! -no-browser"
if %DISABLE_GPU%==1 set "OPTS=!OPTS! -disable-gpu-vsync"
if %USE_CEF_SINGLE_PROCESS%==1 set "OPTS=!OPTS! -cef-single-process -no-cef-sandbox"
if %DISABLE_VR%==1 set "OPTS=!OPTS! -vrdisable"
if %LIMIT_THREADS%==1 set "OPTS=!OPTS! -threads 2"

:: Additional optimizations
set "OPTS=!OPTS! -netbuffer 262144 -no-shared-textures -disable-font-subpixel-positioning"

start "" /B /LOW "%STEAM_PATH%" !OPTS!
exit
