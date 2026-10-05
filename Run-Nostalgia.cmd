@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File Run-Nostalgia.ps1
pause
