@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."

git pull
git submodule update --init --recursive

:: Sync the LiteLLM models (requires LITELLM_API_KEY and PowerShell 7+).
:: Use the script from the repo rather than the installed copy so a fresh
:: `git pull` takes effect here too; install_opencode.bat refreshes the config.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%CD%\config\opencode\update_litellm_models.ps1" "%USERPROFILE%\.config\opencode\opencode.jsonc"

