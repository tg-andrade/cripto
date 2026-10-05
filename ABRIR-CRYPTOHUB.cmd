@echo off
setlocal
cd /d "%~dp0"
if exist "build\windows\x64\runner\Release\cryptohub.exe" (
  start "" "build\windows\x64\runner\Release\cryptohub.exe"
  exit /b 0
)
set "CRYPTOHUB_FLUTTER="
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do if not defined CRYPTOHUB_FLUTTER set "CRYPTOHUB_FLUTTER=%%F"
if not defined CRYPTOHUB_FLUTTER set "CRYPTOHUB_FLUTTER=%USERPROFILE%\Desktop\DSDM\flutter\bin\flutter.bat"
if not exist "%CRYPTOHUB_FLUTTER%" (
  echo Flutter nao encontrado no PATH nem em Desktop\DSDM\flutter.
  echo Instale o Flutter e adicione a pasta bin ao PATH.
  pause
  exit /b 1
)
call "%CRYPTOHUB_FLUTTER%" run -d windows
pause
