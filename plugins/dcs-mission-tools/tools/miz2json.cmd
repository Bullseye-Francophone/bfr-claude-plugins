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
rem veaf-tools' own output is captured to a temp log, never shown on success. On
rem failure, stderr gets "miz2json: veaf-tools export failed for <input> (exit N)"
rem followed by the whole log (miz2json.sh shows only its last lines; tailing a
rem UTF-8 log is not reliable in batch, and a failure log is short).
rem Exit codes: 0 success, 1 export failed, 2 usage.
set "DIR=%~dp0"

set "COMPACT=--compact"
if /I "%~1"=="--pretty" ( set "COMPACT=" & shift )
if /I "%~1"=="-p" ( set "COMPACT=" & shift )

rem Resolve at top level (not inside an if-block): %VT% must expand after the
rem preceding `set`, which a parenthesized block would defeat without delayed expansion.
set "VT=%VEAF_TOOLS%"
if not defined VT set "VT=%DIR%bin\windows-x64\veaf-tools.exe"
if not exist "%VT%" if not defined VEAF_TOOLS set "VT=veaf-tools"

set "INPUT=%~1"
if "%INPUT%"=="" goto :usage
set "OUT=%~2"
set "VT_LOG=%TEMP%\miz2json-log-%RANDOM%%RANDOM%%RANDOM%.txt"
if not "%OUT%"=="" goto :exportToFile

rem Every exit is a top-level `exit /b` reached by goto: an `exit /b` nested in a
rem parenthesized block did not carry its code out, so a failed export answered 0.
rem VT_CODE is read right after the call, at top level, for the same reason.
set "TEMP_EXPORT=%TEMP%\miz2json-%RANDOM%%RANDOM%%RANDOM%.json"
"%VT%" export "%INPUT%" "%TEMP_EXPORT%" --format json %COMPACT% --no-pause >"%VT_LOG%" 2>&1
set "VT_CODE=%ERRORLEVEL%"
if not "%VT_CODE%"=="0" goto :temporaryExportFailed
if not exist "%TEMP_EXPORT%" goto :temporaryExportFailed
set "EXPORTED_BYTES=0"
for %%E in ("%TEMP_EXPORT%") do set "EXPORTED_BYTES=%%~zE"
if not defined EXPORTED_BYTES goto :temporaryExportFailed
if "%EXPORTED_BYTES%"=="0" goto :temporaryExportFailed
type "%TEMP_EXPORT%"
del "%TEMP_EXPORT%" 2>nul
del "%VT_LOG%" 2>nul
exit /b 0

:exportToFile
"%VT%" export "%INPUT%" "%OUT%" --format json %COMPACT% --no-pause >"%VT_LOG%" 2>&1
set "VT_CODE=%ERRORLEVEL%"
if not "%VT_CODE%"=="0" goto :exportFailed
if not exist "%OUT%" goto :exportFailed
set "EXPORTED_BYTES=0"
for %%E in ("%OUT%") do set "EXPORTED_BYTES=%%~zE"
if not defined EXPORTED_BYTES goto :exportFailed
if "%EXPORTED_BYTES%"=="0" goto :exportFailed
del "%VT_LOG%" 2>nul
exit /b 0

:temporaryExportFailed
del "%TEMP_EXPORT%" 2>nul
goto :exportFailed

:exportFailed
rem No parenthesized block here: an input path such as "Program Files (x86)" would close it.
if "%VT_CODE%"=="0" goto :noJsonWritten
echo miz2json: veaf-tools export failed for %INPUT% (exit %VT_CODE%) 1>&2
goto :showLog
:noJsonWritten
echo miz2json: veaf-tools export failed for %INPUT% (exit 0 but no JSON written) 1>&2
:showLog
if exist "%VT_LOG%" echo miz2json: veaf-tools output: 1>&2
if exist "%VT_LOG%" type "%VT_LOG%" 1>&2
del "%VT_LOG%" 2>nul
exit /b 1

:usage
echo usage: miz2json.cmd [--pretty] ^<mission-folder-or-.miz^> [output.json] 1>&2
exit /b 2
