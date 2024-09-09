@echo off
taskkill /F /IM steam.exe >nul 2>&1
del "%ProgramFiles(x86)%\Steam\package\packageinfo.vdf" >nul 2>&1
start "" "%ProgramFiles(x86)%\Steam\Steam.exe" -forcesteamupdate -forcepackagedownload -overridepackageurl http://web.archive.org/web/20240717082107if_/media.steampowered.com/client -exitsteam
exit
