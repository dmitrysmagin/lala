@echo off
set WATCOM=C:\Openwatcom
set PATH=%WATCOM%\binnt;%PATH%
set INCLUDE=%WATCOM%\h
cd /d src
wmake palprobe
echo EXITCODE=%ERRORLEVEL%
