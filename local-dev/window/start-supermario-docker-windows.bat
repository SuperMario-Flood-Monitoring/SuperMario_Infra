@echo off
setlocal

cd /d "%~dp0"

echo SuperMario Docker local launcher
echo.
echo Choose run mode:
echo   1) localhost mode
echo      - Open on this PC: http://localhost:5173
echo.
echo   2) IP mode
echo      - Detect this PC's LAN IP
echo      - Open on phone using: http://^<detected-ip^>:5173
echo.

set "HOST_MODE=localhost"
set /p MODE_CHOICE="Select mode [1/2] (default: 1): "
if "%MODE_CHOICE%"=="2" set "HOST_MODE=ip"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-supermario-docker-windows.ps1" -Action up -HostMode %HOST_MODE%

echo.
pause
