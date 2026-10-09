@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."

git pull
git submodule update --init --recursive

:: Sync the LiteLLM models (requires LITELLM_API_KEY and PowerShell 7+)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.config\opencode\update_litellm_models.ps1" "%USERPROFILE%\.config\opencode\opencode.jsonc"

