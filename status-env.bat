@echo off
setlocal
set "ROOT=%~dp0"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\status-state-002-edge-proxy-generated.ps1" %*
