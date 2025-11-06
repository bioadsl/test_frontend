@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E localmente com navegador visível (headed)
REM Uso: run_local_demo.bat [--headed|--headless]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt"

if not exist "%ROOT%\reports" mkdir "%ROOT%\reports" >nul 2>nul

set ARGS=-m e2e --junitxml "%ROOT%\reports\junit.xml" -q "%ROOT%\tests"

set PYTEST_HEADED=1
for %%A in (%*) do (
  if /I "%%A"=="--headless" set PYTEST_HEADED=
  if /I "%%A"=="--headed" set PYTEST_HEADED=1
)

echo Executando: pytest %ARGS% (PYTEST_HEADED=%PYTEST_HEADED%)
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 exit /b 1
exit /b 0