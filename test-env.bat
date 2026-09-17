@echo off
setlocal
set "ROOT=%~dp0"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\test-state-002-edge-proxy.ps1" %*
