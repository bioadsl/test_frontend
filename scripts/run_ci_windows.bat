@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E para uso em Windows runners (CI) com cobertura
REM Uso: run_ci_windows.bat

set ROOT=%~dp0..
set VENV=%ROOT%\.venv

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt"

if not exist "%ROOT%\reports" mkdir "%ROOT%\reports" >nul 2>nul

set ARGS=-m e2e --junitxml "%ROOT%\reports\junit.xml" --cov=. --cov-report=xml:"%ROOT%\reports\coverage.xml" --cov-report=term -q

echo Executando: pytest %ARGS%
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 exit /b 1
exit /b 0