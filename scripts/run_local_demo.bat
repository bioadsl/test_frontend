@echo off
setlocal enabledelayedexpansion

REM Executa testes E2E localmente com navegador visível (headed)
REM Uso: run_local_demo.bat [--headed|--headless]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%REPORTS%\screenshots
set LOGDIR=%ROOT%\logs

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul
for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set TS=%%t
set LOGFILE=%LOGDIR%\local_demo_!TS!.log
echo [INFO] Iniciando run_local_demo em !TS! > "!LOGFILE!"

if not exist "%VENV%\Scripts\python.exe" (
  echo Criando venv em "%VENV%"
  echo [INFO] Criando venv em "%VENV%" >> "!LOGFILE!"
  py -3 -m venv "%VENV%"
)

"%VENV%\Scripts\python.exe" -m pip install -U pip
"%VENV%\Scripts\pip.exe" install -r "%ROOT%\requirements.txt"
if errorlevel 1 (
  echo [ERRO] Falha no pip install (requirements) >> "!LOGFILE!"
  exit /b 1
)

if not exist "%REPORTS%" mkdir "%REPORTS%" >nul 2>nul
if not exist "%SCREENSHOTS%" mkdir "%SCREENSHOTS%" >nul 2>nul

set ARGS=-m e2e --junitxml "%REPORTS%\junit.xml" --html "%REPORTS%\pytest.html" --self-contained-html -q "%ROOT%\tests"

set PYTEST_HEADED=1
for %%A in (%*) do (
  if /I "%%A"=="--keep-screens" set KEEP_SCREENS=1
)

REM Enforce modo headed SEMPRE (+ delay padrão amigável) para apresentação ao vivo
set ARGS=%ARGS% --headed
if not defined STEP_DELAY_MS set STEP_DELAY_MS=1200
if not defined SCREENSHOT_DELAY_MS set SCREENSHOT_DELAY_MS=800

echo Executando: pytest %ARGS% (PYTEST_HEADED=%PYTEST_HEADED%)
echo [INFO] Executando pytest com argumentos: %ARGS% >> "!LOGFILE!"
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 exit /b 1
REM --- LIMPEZA AUTOMÁTICA DE SCREENSHOTS ---
REM Para preservar imagens, use a flag --keep-screens ou defina KEEP_SCREENSHOTS=1.
set DO_CLEANUP=1
if defined KEEP_SCREENS set DO_CLEANUP=0
if /I "%KEEP_SCREENSHOTS%"=="1" set DO_CLEANUP=0

REM --- ABERTURA DO SUMMARY EM NAVEGADOR PADRÃO ---
set SUMMARY=%REPORTS%\summary.html
if not exist "%SUMMARY%" (
  echo [WARN] Arquivo summary.html ausente em "%SUMMARY%" >> "!LOGFILE!"
  echo Summary.html não encontrado. Abrindo pytest.html como alternativa.
  set SUMMARY=%REPORTS%\pytest.html
)

echo [INFO] Abrindo "%SUMMARY%" no navegador padrão (maximizado) >> "!LOGFILE!"
setlocal
set ERROR_OPEN=0
set TIMEOUT_OPEN=25
set REPORTS_ENV=%REPORTS%
powershell -NoProfile -ExecutionPolicy Bypass -Command "
  $summary = $env:SUMMARY;
  $reports = $env:REPORTS_ENV;
  $default = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' -ErrorAction SilentlyContinue;
  $prog = $default.ProgId;
  $exe = '';
  if ($prog -like '*Chrome*') { $exe = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"; if (-not (Test-Path $exe)) { $exe = "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe" } }
  elseif ($prog -like '*MSEdge*') { $exe = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"; if (-not (Test-Path $exe)) { $exe = "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe" } }
  elseif ($prog -like '*Firefox*') { $exe = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"; if (-not (Test-Path $exe)) { $exe = "$env:ProgramFiles(x86)\Mozilla Firefox\firefox.exe" } }
  $proc = $null;
  try {
    if ($exe -and (Test-Path $exe)) { $proc = Start-Process -FilePath $exe -ArgumentList @('--start-maximized', $summary) -PassThru }
    else { $proc = Start-Process -FilePath $summary -PassThru -WindowStyle Maximized }
  } catch { }
  if (-not $proc) { exit 3 }
  $timeoutSec = [int]$env:TIMEOUT_OPEN; if ($timeoutSec -lt 5) { $timeoutSec = 25 }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
    try {
      $p = Get-Process -Id $proc.Id -ErrorAction Stop
      if ($p.MainWindowHandle -ne 0) { exit 0 }
    } catch { break }
    Start-Sleep -Milliseconds 300
  }
  exit 5
"
if errorlevel 5 (
  echo [ERRO] Timeout ao aguardar carregamento da janela do navegador >> "!LOGFILE!"
  set ERROR_OPEN=5
) else if errorlevel 3 (
  echo [ERRO] Falha ao iniciar navegador para "%SUMMARY%" >> "!LOGFILE!"
  set ERROR_OPEN=3
) else (
  echo [INFO] Navegador aberto e janela detectada com sucesso >> "!LOGFILE!"
)
endlocal & set ERROR_OPEN=%ERROR_OPEN%

REM --- CLEANUP DE SCREENSHOTS APÓS CONFIRMAÇÃO ---
set DO_RUN_CLEANUP=1
if "%DO_CLEANUP%"=="0" set DO_RUN_CLEANUP=0
if %ERROR_OPEN% NEQ 0 set DO_RUN_CLEANUP=0

if "%DO_RUN_CLEANUP%"=="1" (
  echo [INFO] Executando cleanup_screens.ps1 em "%SCREENSHOTS%" >> "!LOGFILE!"
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\cleanup_screens.ps1" -ScreenshotsDir "%SCREENSHOTS%"
  if errorlevel 1 (
    echo [ERRO] Falha no cleanup_screens.ps1 >> "!LOGFILE!"
    exit /b 4
  ) else (
    echo [INFO] Cleanup concluído com sucesso >> "!LOGFILE!"
  )
) else (
  echo [INFO] Cleanup de screenshots ignorado (ERROR_OPEN=%ERROR_OPEN% DO_CLEANUP=%DO_CLEANUP%) >> "!LOGFILE!"
)

echo [INFO] Finalizando run_local_demo (ok) >> "!LOGFILE!"
exit /b 0