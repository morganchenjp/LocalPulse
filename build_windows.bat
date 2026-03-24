@echo off
REM LANShare Windows Build Script
REM Run this on a Windows machine with Flutter installed
REM Output: dist\LANShare-windows-x64.zip

echo [1/4] Checking Flutter...
flutter --version
if errorlevel 1 (
    echo ERROR: Flutter not found. Install from https://flutter.dev
    exit /b 1
)

echo [2/4] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get failed
    exit /b 1
)

echo [3/4] Building Windows release...
call flutter build windows --release
if errorlevel 1 (
    echo ERROR: Build failed
    exit /b 1
)

echo [4/4] Packaging ZIP...
if not exist dist mkdir dist
powershell -Command "Compress-Archive -Force -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'dist\LANShare-1.0.0-windows-x64.zip'"

echo.
echo ========================================
echo   BUILD COMPLETE
echo   Output: dist\LANShare-1.0.0-windows-x64.zip
echo ========================================
echo.
echo To run: Extract ZIP and double-click lan_share.exe
