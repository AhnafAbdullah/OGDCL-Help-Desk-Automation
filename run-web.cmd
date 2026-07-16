@echo off
REM Starts the OGDCL web dashboard on http://localhost:5090
REM Start run-api.cmd FIRST - the dashboard calls the API on port 5080.
cd /d "%~dp0backend"
echo Starting OGDCL web dashboard on http://localhost:5090 ...
echo (Make sure run-api.cmd is already running.)
echo Press Ctrl+C to stop.
echo.
dotnet run --project src/Ogdcl.Web --urls http://localhost:5090
echo.
echo The dashboard stopped. Press any key to close this window.
pause >nul
