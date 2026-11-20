@echo off
cd /d "%~dp0"
if "%1"=="" (
  set "theCommand=apply"
  set "theArgs=-auto-approve -compact-warnings"
  rem  -replace=oci_core_instance.compute_instance"
) else if "%1"=="destroy" (
  set "theCommand=apply -destroy"
  set "theArgs=-auto-approve"
) else (
  set "theCommand=%1"
  shift
  set "theArgs=%*"
)
terraform %theCommand%  %theArgs%