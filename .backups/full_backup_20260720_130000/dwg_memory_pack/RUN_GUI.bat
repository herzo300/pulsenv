@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 app\dwg_memory_gui.py
  goto :done
)

where python >nul 2>nul
if %ERRORLEVEL%==0 (
  python app\dwg_memory_gui.py
  goto :done
)

echo Python 3 is not found. Install Python 3.11+ and try again.
pause

:done
endlocal
