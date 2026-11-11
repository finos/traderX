@echo off
echo [info] no state-specific test entrypoint was detected for this snapshot.
if exist "%~dp0scripts" (
  echo [hint] available test scripts:
  dir /b "%~dp0scripts\test-state-*.ps1" 2>nul
  dir /b "%~dp0scripts\test-state-*.sh" 2>nul
)
exit /b 2
