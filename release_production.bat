@echo off
echo Preparing Production Release for Play Store (AAB)...
pushd source
echo Cleaning project...
call flutter clean
echo Fetching dependencies...
call flutter pub get
echo Generating code...
call dart run build_runner build --delete-conflicting-outputs
echo Building Android App Bundle (AAB)...
call flutter build appbundle --release
echo Building Android APK...
call flutter build apk --release
popd
echo.
echo Production Files Ready:
echo AAB: source\build\app\outputs\bundle\release\app-release.aab
echo APK: source\build\app\outputs\flutter-apk\app-release.apk
echo.
pause
