@echo off
rem G's Avengers - one double-click install for Windows: builds, checks, installs, starts.
cd /d "%~dp0"
echo Stopping Deskflow (if running) so the two don't fight over the mouse...
taskkill /im deskflow.exe /f >nul 2>&1
taskkill /im deskflow-core.exe /f >nul 2>&1
taskkill /im deskflow-server.exe /f >nul 2>&1
call build.cmd || ( echo Using the ready-made copy instead. & copy /y prebuilt\GsAvengers.exe GsAvengers.exe >nul || goto :fail )
GsAvengers.exe --selftest --portable
if errorlevel 1 ( echo Crypto self-test FAILED - see %LOCALAPPDATA%\GsAvengers\selftest.txt & goto :fail )
echo Self-test passed. Installing...
start "" GsAvengers.exe
echo Done. Look for the G's Avengers window and the tray icon.
exit /b 0
:fail
echo Something went wrong. Copy the text above into an issue: https://github.com/GauthamWho/GsAvengers/issues
pause
exit /b 1
