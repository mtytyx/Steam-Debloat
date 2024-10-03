@echo off
setlocal enabledelayedexpansion

:: Steam Test Launcher
:: Highly configurable options for testing different optimization levels

set "STEAM_PATH=C:\Program Files (x86)\Steam\steam.exe"

:: Base options
set "BASE_OPTS=-noverifyfiles -norepairfiles -noshaders -nocrashdialog -single_core -tcp -clearbeta -cef-force-32bit"

:: Toggleable options (0 = off, 1 = on)
set "DISABLE_BROWSER=1"
set "DISABLE_GPU=1"
set "USE_CEF_SINGLE_PROCESS=1"
set "DISABLE_VR=1"
set "LIMIT_THREADS=1"

:: Build options string
set "OPTS=!BASE_OPTS!"
if %DISABLE_BROWSER%==1 set "OPTS=!OPTS! -no-browser"
if %DISABLE_GPU%==1 set "OPTS=!OPTS! -disable-gpu-vsync -disable-gpu"
if %USE_CEF_SINGLE_PROCESS%==1 set "OPTS=!OPTS! -cef-single-process -no-cef-sandbox"
if %DISABLE_VR%==1 set "OPTS=!OPTS! -vrdisable"
if %LIMIT_THREADS%==1 set "OPTS=!OPTS! -threads 2"

:: Additional optimizations
set "OPTS=!OPTS! -netbuffer 131072 -no-shared-textures -disable-font-subpixel-positioning -disable-smooth-scrolling -console"

start "" /B /LOW "%STEAM_PATH%" !OPTS!
exit
