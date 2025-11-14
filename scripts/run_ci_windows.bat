@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E para uso em Windows runners (CI) com cobertura
REM Uso: run_ci_windows.bat

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%ROOT%\screenshots
set LOGDIR=%ROOT%\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set TS=%%t
set LOGFILE=%LOGDIR%\ci_run_!TS!.log
echo [INFO] Iniciando run_ci_windows em !TS! > "!LOGFILE!"
echo Iniciando run_ci_windows em !TS!
REM Garantir headless no CI: limpar qualquer herança de PYTEST_HEADED
set PYTEST_HEADED=

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt" -q >> "!LOGFILE!" 2>&1
echo [INFO] Dependencias instaladas/verificadas >> "!LOGFILE!"
echo Dependencias instaladas/verificadas

if not exist "%REPORTS%" mkdir "%REPORTS%" >nul 2>nul
if not exist "%SCREENSHOTS%" mkdir "%SCREENSHOTS%" >nul 2>nul

set ARGS=-m e2e --junitxml "%REPORTS%\junit.xml" --html "%REPORTS%\pytest.html" --self-contained-html --cov=. --cov-report=xml:"%REPORTS%\coverage.xml" --cov-report=term -q "%ROOT%\tests"

REM Flag opcional para manter screenshots
set KEEP_SCREENS=
for %%A in (%*) do (
  if /I "%%A"=="--keep-screens" set KEEP_SCREENS=1
)

echo Executando: pytest %ARGS%
echo [INFO] Executando pytest com argumentos: %ARGS% >> "!LOGFILE!"
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 (
  echo [ERRO] Pytest retornou erro. >> "!LOGFILE!"
  exit /b 1
)
REM --- LIMPEZA AUTOMÁTICA DE SCREENSHOTS ---
REM Para preservar imagens, use a flag --keep-screens ou defina KEEP_SCREENSHOTS=1.
set DO_CLEANUP=1
if defined KEEP_SCREENS set DO_CLEANUP=0
if /I "%KEEP_SCREENSHOTS%"=="1" set DO_CLEANUP=0

if "%DO_CLEANUP%"=="1" (
  echo Executando cleanup de screenshots...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\cleanup_screens.ps1" -ScreenshotsDir "%SCREENSHOTS%"
) else (
  echo Mantendo screenshots (KEEP_SCREENS=%KEEP_SCREENS% KEEP_SCREENSHOTS=%KEEP_SCREENSHOTS%).
)
echo [INFO] Finalizando run_ci_windows (ok) >> "!LOGFILE!"
echo Finalizado run_ci_windows.
exit /b 0