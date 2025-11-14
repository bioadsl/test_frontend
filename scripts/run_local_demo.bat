@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E localmente com navegador visível (headed)
REM Uso: run_local_demo.bat [--headed|--headless]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%ROOT%\screenshots
set LOGDIR=%ROOT%\logs

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set TS=%%t
set LOGFILE=%LOGDIR%\local_demo_!TS!.log
set LOGLATEST=%LOGDIR%\local_demo_latest.log
type NUL > "!LOGLATEST!"
echo [INFO] Iniciando run_local_demo em !TS! > "!LOGFILE!"
echo [INFO] Iniciando run_local_demo em !TS! > "!LOGLATEST!"
echo Iniciando run_local_demo em !TS!

if not exist "%REPORTS%" mkdir "%REPORTS%" >nul 2>nul
if not exist "%SCREENSHOTS%" mkdir "%SCREENSHOTS%" >nul 2>nul

REM Delays amigáveis para screenshots
if not defined STEP_DELAY_MS set STEP_DELAY_MS=1200
if not defined SCREENSHOT_DELAY_MS set SCREENSHOT_DELAY_MS=800
set PYTEST_HEADED=1
for %%A in (%*) do (
  if /I "%%A"=="--keep-screens" set KEEP_SCREENS=1
)

REM Executar testes via PowerShell runner (mais robusto)
echo Executando testes (headed) via run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\run_tests.ps1" -JUnitXml "%REPORTS%\junit.xml" -HtmlReport "%REPORTS%\pytest.html" -Headed
if errorlevel 1 (
  echo Erro na execução dos testes. Consulte logs em "%LOGDIR%" e "reports\pytest.html".
  exit /b 1
)

REM --- PREPARAÇÃO/VALIDAÇÃO DE SCREENSHOTS ---
echo [INFO] Preparando/validando screenshots em "%SCREENSHOTS%" >> "!LOGFILE!"
echo [INFO] Preparando/validando screenshots em "%SCREENSHOTS%" >> "!LOGLATEST!"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\prepare_screenshots.ps1" -Root "%ROOT%" -ScreenshotsDir "%SCREENSHOTS%" -SummaryPath "%REPORTS%\action.html" -VerboseLog
if errorlevel 1 (
  echo [ERROR] Falha na preparação de screenshots. Veja o console/log. >> "!LOGFILE!"
  echo [ERROR] Falha na preparação de screenshots. Veja o console/log. >> "!LOGLATEST!"
  REM Não aborta a execução; segue para abertura do summary
) else (
  echo [INFO] Preparação/validação de screenshots concluída. >> "!LOGFILE!"
  echo [INFO] Preparação/validação de screenshots concluída. >> "!LOGLATEST!"
)
REM --- LIMPEZA AUTOMÁTICA DE SCREENSHOTS ---
REM Para preservar imagens, use a flag --keep-screens ou defina KEEP_SCREENSHOTS=1.
set DO_CLEANUP=1
if defined KEEP_SCREENS set DO_CLEANUP=0
if /I "%KEEP_SCREENSHOTS%"=="1" set DO_CLEANUP=0

REM --- ABERTURA DO SUMMARY EM NAVEGADOR PADRÃO ---
set SUMMARY=%REPORTS%\action.html
if not exist "%SUMMARY%" (
  echo [WARN] Arquivo action.html ausente em "%SUMMARY%" >> "!LOGFILE!"
  echo [WARN] Arquivo action.html ausente em "%SUMMARY%" >> "!LOGLATEST!"
  echo action.html não encontrado. Abrindo pytest.html como alternativa.
  set SUMMARY=%REPORTS%\pytest.html
)

echo [INFO] Abrindo "%SUMMARY%" no navegador padrão (maximizado) >> "!LOGFILE!"
echo [INFO] Abrindo "%SUMMARY%" no navegador padrão (maximizado) >> "!LOGLATEST!"
echo Abrindo relatório: "%SUMMARY%"
set ERROR_OPEN=0
echo [INFO] Abrindo action via shell padrão: "%SUMMARY%" >> "!LOGFILE!"
start "" "%SUMMARY%"
REM Considerar abertura como não bloqueante; não travar cleanup
set ERROR_OPEN=0

REM --- CLEANUP DE SCREENSHOTS APÓS CONFIRMAÇÃO ---
set DO_RUN_CLEANUP=1
if "%DO_CLEANUP%"=="0" set DO_RUN_CLEANUP=0
REM Cleanup não depende da abertura do navegador

if "%DO_RUN_CLEANUP%"=="1" (
  echo [INFO] Executando cleanup_screens.ps1 em "%SCREENSHOTS%" >> "!LOGFILE!"
  echo [INFO] Executando cleanup_screens.ps1 em "%SCREENSHOTS%" >> "!LOGLATEST!"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\cleanup_screens.ps1" -ScreenshotsDir "%SCREENSHOTS%"
  if errorlevel 1 (
    echo [ERRO] Falha no cleanup_screens.ps1 >> "!LOGFILE!"
    echo [ERRO] Falha no cleanup_screens.ps1 >> "!LOGLATEST!"
    exit /b 4
  ) else (
    echo [INFO] Cleanup concluído com sucesso >> "!LOGFILE!"
    echo [INFO] Cleanup concluído com sucesso >> "!LOGLATEST!"
  )
) else (
  echo [INFO] Cleanup de screenshots ignorado (DO_CLEANUP=%DO_CLEANUP%) >> "!LOGFILE!"
  echo [INFO] Cleanup de screenshots ignorado (DO_CLEANUP=%DO_CLEANUP%) >> "!LOGLATEST!"
)

echo [INFO] Finalizando run_local_demo (ok) >> "!LOGFILE!"
echo [INFO] Finalizando run_local_demo (ok) >> "!LOGLATEST!"
echo Execução concluída. Relatório em: "%SUMMARY%"

REM Atualiza arquivos de status e histórico para consumo pelo action.html
powershell -NoProfile -ExecutionPolicy Bypass -Command "
$root = Resolve-Path '%ROOT%';
$reports = Join-Path $root 'reports';
$logs = Join-Path $root 'logs';
$livePath = Join-Path $reports 'live.json';
$histPath = Join-Path $logs 'local_demo_history.json';
$now = Get-Date;
$status = 'success';
$record = [pscustomobject]@{ timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss'); file = '%LOGFILE%'; latest = '%LOGLATEST%'; status = $status };
try {
  $payload = [pscustomobject]@{ lastRun = $now.ToString('yyyy-MM-dd HH:mm:ss'); status = $status; summary = (Resolve-Path '%SUMMARY%').Path; log = (Resolve-Path '%LOGFILE%').Path };
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false);
  [System.IO.File]::WriteAllText($livePath, ($payload | ConvertTo-Json -Depth 4), $utf8NoBom);
} catch {}
try {
  $hist = @(); if (Test-Path -LiteralPath $histPath) { try { $hist = Get-Content -LiteralPath $histPath -Raw | ConvertFrom-Json } catch { $hist = @() } }
  $hist = @($record) + @($hist | Select-Object -First 49);
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false);
  [System.IO.File]::WriteAllText($histPath, ($hist | ConvertTo-Json -Depth 4), $utf8NoBom);
} catch {}
"
exit /b 0