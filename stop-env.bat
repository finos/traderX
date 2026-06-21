@echo off
setlocal
set "ROOT=%~dp0"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\stop-base-uncontainerized-generated.ps1" %*
