@echo off
:: ============================================
::   WSL2 + Ubuntu-24.04 Automated Setup
::   Ericsson Internal - Dylan Smith
:: ============================================
:: Double-click this file to start.
:: It will request admin privileges automatically.

echo.
echo   ============================================
echo     WSL2 + Ubuntu-24.04 Automated Setup
echo   ============================================
echo.

:: Self-elevate to admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~dp0install-wsl.bat' -Verb RunAs"
    exit /b
)

:: Run the PowerShell setup script
powershell -ExecutionPolicy Bypass -File "%~dp0setup-wsl.ps1"
