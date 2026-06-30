@echo off
echo Running MyCompanyApp Update...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0MyCompanyApp.Updater.ps1" %*
pause
