@echo off
cd /d "%~dp0"
echo =============================================
echo   DocuNet Backend Setup
echo =============================================
echo.

REM Check Python
py --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python Launcher not found. Please install official Windows Python from python.org
    pause
    exit /b 1
)

REM Install Python dependencies
echo Installing Python packages...
py -m pip install --user -r requirements.txt

if errorlevel 1 (
    echo [ERROR] Failed to install packages.
    pause
    exit /b 1
)

echo.
echo =============================================
echo   Starting DocuNet API Server
echo =============================================
echo.
echo Backend URL: http://localhost:8000
echo Docs:        http://localhost:8000/docs
echo.
echo Find your LAN IP to use in Flutter:
ipconfig | findstr "IPv4"
echo.
echo.

py -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload
pause
