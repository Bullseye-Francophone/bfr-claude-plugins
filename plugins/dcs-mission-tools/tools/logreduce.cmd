@echo off
setlocal
set "DIR=%~dp0"
set "BIN=%DIR%bin\windows-x64\lua54.exe"
if not exist "%BIN%" set "BIN=lua"
"%BIN%" "%DIR%src\logmain.lua" %*
exit /b %errorlevel%
