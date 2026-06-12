@echo off
echo ==========================================
echo   MFTracker Web Build & Deploy Script
echo ==========================================
echo.

echo [1/4] Cleaning previous builds...
pushd source
call flutter clean
echo.

echo [2/4] Building Flutter Web (Base: /mftracker/)...
call flutter build web --release --base-href "/mftracker/"
popd
echo.

echo [3/4] Deploying files to root...
:: Copy built files to root for GitHub Pages
xcopy /E /I /Y source\build\web\* .
echo.

echo [4/4] Starting development server...
echo Access at: http://localhost:8080/mftracker/
echo.
echo NOTE: Running in INCOGNITO mode to prevent cache and auth state issues.
echo.

pushd source
:: Run with specific port and incognito flag to ensure Google Sign-In works
:: Force port 8080 to match Google Cloud Console 'Authorized JavaScript origins'
call flutter run -d chrome --web-port 8080 --web-browser-flag="--incognito"
popd
pause