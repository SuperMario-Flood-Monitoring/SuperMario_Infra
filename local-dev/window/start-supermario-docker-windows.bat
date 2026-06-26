@echo off
setlocal

cd /d "%~dp0"

if "%~1"=="" goto interactive

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-supermario-docker-windows.ps1" %*
exit /b %ERRORLEVEL%

:interactive

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
if "%MODE_CHOICE%"=="" set "HOST_MODE=localhost"
if "%MODE_CHOICE%"=="1" set "HOST_MODE=localhost"
if "%MODE_CHOICE%"=="2" set "HOST_MODE=ip"

if not "%MODE_CHOICE%"=="" if not "%MODE_CHOICE%"=="1" if not "%MODE_CHOICE%"=="2" (
  echo Unknown choice: %MODE_CHOICE%
  echo.
  pause
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-supermario-docker-windows.ps1" -Action up -HostMode %HOST_MODE%
set "STATUS=%ERRORLEVEL%"

if not "%STATUS%"=="0" (
  echo.
  echo Docker start failed.
  echo.
  echo If the log contains "failed to fetch oauth token" or "401 Unauthorized",
  echo Docker Desktop cannot currently pull public images from Docker Hub.
  echo.
  echo Try:
  echo   docker logout
  echo   docker login
  echo.
  echo Then run this file again.
)

echo.
pause
exit /b %STATUS%
