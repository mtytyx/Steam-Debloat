@echo off
cd /d "C:\Program Files (x86)\Steam"
start steam.exe -silent -cef-force-32bit -no-browser -no-dwrite -no-cef-sandbox -nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -720p -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -console
