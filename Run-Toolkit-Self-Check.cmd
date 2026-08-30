@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "WinCare-Toolkit-v2.3.2.ps1" -Mode SelfCheck
if errorlevel 1 (
  echo.
  echo WinCare Toolkit Self Check ended with an error.
  pause
)
