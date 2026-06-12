@echo off
echo ==========================================
echo   MFTracker Android Launch Script
echo ==========================================
echo.

echo [1/4] Checking for running devices...
:: Check if any android device is already connected/running
call flutter.bat devices | findstr /i "android" > nul
if %errorlevel% equ 0 (
    echo -> Active Android device/emulator already detected.
) else (
    echo -> No active device found. Launching emulator: Phone...
    call flutter.bat emulators --launch Phone
)

echo.
echo [2/4] Ensuring device is ready...
:wait_loop
timeout /t 3 /nobreak > nul
call flutter.bat devices | findstr /i "android" > nul
if %errorlevel% neq 0 (
    echo -> Still waiting for device to come online...
    goto wait_loop
)
echo -> Device is ready!

echo [3/4] Removing existing app for a clean install...
set "ADB_EXE=adb"
where adb >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
        set "ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
    )
)
%ADB_EXE% uninstall com.intellicast.mftracker
echo.

echo [4/4] Installing and Launching App...
pushd source
call flutter.bat run
popd

echo.
echo Done!
pause
