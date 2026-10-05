@echo off
setlocal
cd /d "%~dp0"
if exist "build\windows\x64\runner\Release\cryptohub.exe" (
  start "" "build\windows\x64\runner\Release\cryptohub.exe"
  exit /b 0
)
set "CRYPTOHUB_FLUTTER=%USERPROFILE%\Desktop\DSDM\flutter\bin\flutter.bat"
if not exist "%CRYPTOHUB_FLUTTER%" (
  echo Flutter nao encontrado em Desktop\DSDM\flutter.
  echo Abra o terminal nesta pasta e execute: flutter run -d windows
  pause
  exit /b 1
)
call "%CRYPTOHUB_FLUTTER%" run -d windows
pause
