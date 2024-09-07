@echo off
setlocal enabledelayedexpansion

set "PS_SCRIPT_URL=https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/app.ps1"
set "PS_SCRIPT_FILE=app.ps1"

powershell -Command "Invoke-WebRequest -Uri '%PS_SCRIPT_URL%' -OutFile '%TEMP%\%PS_SCRIPT_FILE%'"
if %errorlevel% neq 0 (
    echo [ERROR] Could not download %PS_SCRIPT_FILE%.
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%TEMP%\%PS_SCRIPT_FILE%" -Mode "Normal"
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell script execution failed.
    exit /b 1
)

del "%TEMP%\%PS_SCRIPT_FILE%"
exit /b
