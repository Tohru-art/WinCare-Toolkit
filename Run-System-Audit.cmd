@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "WinCare-Toolkit-v2.3.2.ps1" -Mode Audit
if errorlevel 1 pause
