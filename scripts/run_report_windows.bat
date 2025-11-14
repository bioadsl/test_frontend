@echo off
setlocal enabledelayedexpansion

REM Executa pytest, gera JUnit + HTML, abre HTML e cria resumo com screenshots
REM Uso: run_report_windows.bat [--headed]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%ROOT%\screenshots
set HTML_REPORT=%REPORTS%\pytest.html
set JUNIT=%REPORTS%\junit.xml
set SUMMARY=%REPORTS%\action.html

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt"

if not exist "%REPORTS%" mkdir "%REPORTS%" >nul 2>nul
if not exist "%SCREENSHOTS%" mkdir "%SCREENSHOTS%" >nul 2>nul

set ARGS=-m e2e --junitxml "%JUNIT%" --html "%HTML_REPORT%" --self-contained-html -q "%ROOT%\tests"

REM Modo headed opcional
set PYTEST_HEADED=
set STEP_DELAY_OPT=
set SHOT_DELAY_OPT=
set KEEP_SCREENS=
for %%A in (%*) do (
  if /I "%%A"=="--headed" set PYTEST_HEADED=1
  rem Suporta formato --step-delay=0.7
  echo %%A | findstr /I /B /C:"--step-delay=" >nul && set STEP_DELAY_OPT=%%A
  rem Novo: suporta formato --shot-delay-ms=800 (delay antes da screenshot)
  echo %%A | findstr /I /B /C:"--shot-delay-ms=" >nul && set SHOT_DELAY_OPT=%%A
  rem Novo: manter screenshots apos execução se flag presente
  if /I "%%A"=="--keep-screens" set KEEP_SCREENS=1
)

if defined STEP_DELAY_OPT (
  set ARGS=%ARGS% %STEP_DELAY_OPT%
)
if defined SHOT_DELAY_OPT (
  set ARGS=%ARGS% %SHOT_DELAY_OPT%
)

echo Executando: pytest %ARGS% (PYTEST_HEADED=%PYTEST_HEADED%)
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 (
  echo Pytest retornou erro. Ainda assim, gerando resumo e abrindo HTML...
)

REM Preparação/validação de screenshots antes de incluir no resumo
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\prepare_screenshots.ps1" -Root "%ROOT%" -ScreenshotsDir "%SCREENSHOTS%" -SummaryPath "%SUMMARY%" -VerboseLog
if errorlevel 1 (
  echo [ERRO] Falha na preparação de screenshots. Continuando com o restante.
)

REM Abrir relatório HTML padrão do pytest
powershell -NoProfile -Command "Invoke-Item (Resolve-Path '%HTML_REPORT%')"

REM Opcional: abrir página de ações (resumo)
REM powershell -NoProfile -Command "Invoke-Item (Resolve-Path '%SUMMARY%')"

REM --- LIMPEZA AUTOMÁTICA DE SCREENSHOTS ---
REM Comentário (PT-BR): Após a conclusão, removemos screenshots para evitar acúmulo.
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