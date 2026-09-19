@echo off
setlocal
cd /d "%~dp0"
start "KitHub Studio Bridge" powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\studio_bridge.ps1" -RepoRoot "%~dp0" -Port 8765
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:8765/"
