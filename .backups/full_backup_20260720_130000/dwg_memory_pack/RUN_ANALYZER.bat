@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  echo Usage:
  echo   RUN_ANALYZER.bat path\to\drawing_dwg_index.json
  pause
  exit /b 1
)

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 app\dwg_analyzer.py "%~1"
  goto :done
)

python app\dwg_analyzer.py "%~1"

:done
pause
endlocal
