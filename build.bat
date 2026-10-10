@echo off
rem build.bat — builds the game with Open Watcom (run from repo root).
rem Usage: build [wmake-target]  (default: all -> bin\lala.exe, bin\test.exe, bin\musplay.exe)
rem Examples: build       | build clean | build dqblib
set WATCOM=C:\Openwatcom
set PATH=C:\Openwatcom\binnt;%PATH%
set INCLUDE=C:\Openwatcom\h
wmake %*
