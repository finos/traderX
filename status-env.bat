@echo off
setlocal
set "ROOT=%~dp0"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\status-base-uncontainerized-generated.ps1" %*
