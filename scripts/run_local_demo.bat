@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E localmente com navegador visível (headed)
REM Uso: run_local_demo.bat [--headed|--headless]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%REPORTS%\screenshots

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt"

if not exist "%REPORTS%" mkdir "%REPORTS%" >nul 2>nul
if not exist "%SCREENSHOTS%" mkdir "%SCREENSHOTS%" >nul 2>nul

set ARGS=-m e2e --junitxml "%REPORTS%\junit.xml" -q "%ROOT%\tests"

set PYTEST_HEADED=1
for %%A in (%*) do (
  if /I "%%A"=="--headless" set PYTEST_HEADED=
  if /I "%%A"=="--headed" set PYTEST_HEADED=1
  if /I "%%A"=="--keep-screens" set KEEP_SCREENS=1
)

echo Executando: pytest %ARGS% (PYTEST_HEADED=%PYTEST_HEADED%)
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 exit /b 1
REM --- LIMPEZA AUTOMÁTICA DE SCREENSHOTS ---
REM Para preservar imagens, use a flag --keep-screens ou defina KEEP_SCREENSHOTS=1.
set DO_CLEANUP=1
if defined KEEP_SCREENS set DO_CLEANUP=0
if /I "%KEEP_SCREENSHOTS%"=="1" set DO_CLEANUP=0

if "%DO_CLEANUP%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\cleanup_screens.ps1" -ScreenshotsDir "%SCREENSHOTS%"
) else (
  echo Mantendo screenshots (KEEP_SCREENS=%KEEP_SCREENS% KEEP_SCREENSHOTS=%KEEP_SCREENSHOTS%).
)
exit /b 0