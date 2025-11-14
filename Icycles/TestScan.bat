@echo off
echo ========================================
echo ICYCLES - Manual Desktop Scan Test
echo ========================================
echo.

set DESKTOP=%USERPROFILE%\Desktop
set OUTPUT=%~dp0Data\TempFileList.txt

echo Desktop Path: %DESKTOP%
echo Output File: %OUTPUT%
echo.

echo Testing dir command...
dir "%DESKTOP%" /B

echo.
echo Writing to temp file...
dir "%DESKTOP%" /B > "%OUTPUT%"

if exist "%OUTPUT%" (
    echo SUCCESS: File created!
    echo.
    echo Contents of TempFileList.txt:
    type "%OUTPUT%"
    echo.
    echo Line count:
    find /c /v "" < "%OUTPUT%"
) else (
    echo ERROR: File was not created!
)

echo.
pause
