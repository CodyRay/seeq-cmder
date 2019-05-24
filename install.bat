@echo off

cd /d %~dp0
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\util\install.ps1'"
pause
