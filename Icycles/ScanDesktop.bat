@echo off
REM Icycles Desktop Scanner Helper
REM This batch file scans the Desktop and writes to TempFileList.txt

set OUTPUT=%~dp0Data\TempFileList.txt

REM Create Data folder if it doesn't exist
if not exist "%~dp0Data" mkdir "%~dp0Data"

REM Scan Desktop and write to temp file
dir "%USERPROFILE%\Desktop" /B > "%OUTPUT%" 2>nul

REM Exit silently
exit /b 0
