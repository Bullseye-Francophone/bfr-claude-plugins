@echo off
setlocal
rem miz2json — export a DCS mission (extracted folder or packed .miz) to JSON via
rem veaf-tools (pure-Python parse, never runs Lua). Emits JSON on stdout for jq /
rem python. See knowledge\vanilla\mission-json.md for the contract and recipes.
rem
rem   miz2json.cmd [--pretty] <mission-folder-or-.miz> [output.json]
rem
rem --pretty  emit indented JSON (one value per line) for the no-jq grep fallback;
rem           the default is compact (best for jq).
rem veaf-tools resolution mirrors mizlint.cmd: %VEAF_TOOLS% override, then the
rem vendored bin\windows-x64\veaf-tools.exe, then `veaf-tools` on PATH.
set "DIR=%~dp0"

set "COMPACT=--compact"
if /I "%~1"=="--pretty" ( set "COMPACT=" & shift )
if /I "%~1"=="-p" ( set "COMPACT=" & shift )

if defined VEAF_TOOLS (
  set "VT=%VEAF_TOOLS%"
) else (
  set "VT=%DIR%bin\windows-x64\veaf-tools.exe"
  if not exist "%VT%" set "VT=veaf-tools"
)

set "INPUT=%~1"
if "%INPUT%"=="" (
  echo usage: miz2json.cmd [--pretty] ^<mission-folder-or-.miz^> [output.json] 1>&2
  exit /b 2
)
set "OUT=%~2"

if not "%OUT%"=="" (
  "%VT%" export "%INPUT%" "%OUT%" --format json %COMPACT% --no-pause >nul 2>&1
  if errorlevel 1 (
    echo miz2json: veaf-tools export failed for %INPUT% 1>&2
    exit /b 1
  )
  exit /b 0
)

set "TMP=%TEMP%\miz2json-%RANDOM%%RANDOM%.json"
"%VT%" export "%INPUT%" "%TMP%" --format json %COMPACT% --no-pause >nul 2>&1
if errorlevel 1 (
  del "%TMP%" 2>nul
  echo miz2json: veaf-tools export failed for %INPUT% 1>&2
  exit /b 1
)
type "%TMP%"
del "%TMP%" 2>nul
exit /b 0
