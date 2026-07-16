@echo off
REM Starts the OGDCL API on http://localhost:5080
REM Works no matter which folder you run it from (%~dp0 = this script's folder).
cd /d "%~dp0backend"
echo Starting OGDCL API on http://localhost:5080 ...
echo Press Ctrl+C to stop.
echo.
dotnet run --project src/Ogdcl.Api --urls http://localhost:5080
echo.
echo The API stopped. Press any key to close this window.
pause >nul
