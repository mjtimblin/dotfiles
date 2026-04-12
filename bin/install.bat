@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."

git pull
git submodule update --init --recursive

if not exist "%USERPROFILE%\.config\opencode" mkdir "%USERPROFILE%\.config\opencode"
if not exist "%USERPROFILE%\.agents" mkdir "%USERPROFILE%\.agents"

xcopy /E /Y /Q "%CD%\opencode\*" "%USERPROFILE%\.config\opencode\"
xcopy /E /Y /Q "%CD%\agents\*" "%USERPROFILE%\.agents\"

