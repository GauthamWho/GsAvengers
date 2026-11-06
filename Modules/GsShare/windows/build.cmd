@echo off
rem G's Avengers - builds GsAvengers.exe with the C# compiler that ships inside Windows (nothing to install).
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" ( echo C# compiler not found in Windows. & exit /b 1 )
"%CSC%" /nologo /target:winexe /optimize+ /platform:anycpu /win32icon:icon.ico /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Core.dll /r:System.Numerics.dll /out:GsAvengers.exe src\*.cs
if errorlevel 1 ( echo BUILD FAILED & exit /b 1 )
echo BUILD OK: %~dp0GsAvengers.exe
