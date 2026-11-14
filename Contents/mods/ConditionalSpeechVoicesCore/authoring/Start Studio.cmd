@echo off
where py >nul 2>nul
if not errorlevel 1 (
  py -3 -B "%~dp0tools\launch_studio.py"
) else (
  python -B "%~dp0tools\launch_studio.py"
)
if errorlevel 1 (
  echo.
  echo Requirements: Python 3.11 or newer and FFmpeg on PATH.
  pause
)
