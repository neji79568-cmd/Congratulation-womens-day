@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-site.ps1"
start "" "http://localhost:5500/"
