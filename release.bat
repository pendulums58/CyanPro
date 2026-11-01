@echo off
rem Build cyanpro.exe and collect the GitHub release files. See tools\release.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\release.ps1"
pause
