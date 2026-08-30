@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "WinCare-Toolkit-v2.3.2.ps1" -Mode Menu
if errorlevel 1 (
  echo.
  echo WinCare Toolkit could not start or ended with an error.
  echo The window is being kept open so you can read the message above.
  echo.
  pause
)
