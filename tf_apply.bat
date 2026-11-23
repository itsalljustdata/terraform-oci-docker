@echo off
setlocal
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if not errorlevel 1 (
  set "PowerShellHost=pwsh.exe"
) else (
  set "PowerShellHost=powershell.exe"
)

"%PowerShellHost%" -NoProfile -ExecutionPolicy Bypass -File ".\tf_apply.ps1" %*
exit /b %ERRORLEVEL%