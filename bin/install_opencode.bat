@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."

if not exist "%USERPROFILE%\.config\opencode" mkdir "%USERPROFILE%\.config\opencode"
if not exist "%USERPROFILE%\.config\cortexkit" mkdir "%USERPROFILE%\.config\cortexkit"
if not exist "%USERPROFILE%\.agents" mkdir "%USERPROFILE%\.agents"

xcopy /E /Y /Q "%CD%\config\opencode\*" "%USERPROFILE%\.config\opencode\"
xcopy /E /Y /Q "%CD%\config\cortexkit\*" "%USERPROFILE%\.config\cortexkit\"
xcopy /E /Y /Q "%CD%\agents\*" "%USERPROFILE%\.agents\"

:: Sync the LiteLLM models (requires LITELLM_API_KEY and PowerShell 7+)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.config\opencode\update_litellm_models.ps1" "%USERPROFILE%\.config\opencode\opencode.jsonc"
