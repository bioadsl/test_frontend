@echo off
setlocal enabledelayedexpansion

REM Executa pytest, gera JUnit + HTML, abre HTML e cria resumo com screenshots
REM Uso: run_report_windows.bat [--headed]

set ROOT=%~dp0..
set VENV=%ROOT%\.venv
set REPORTS=%ROOT%\reports
set SCREENSHOTS=%REPORTS%\screenshots
set HTML_REPORT=%REPORTS%\pytest.html
set JUNIT=%REPORTS%\junit.xml
set SUMMARY=%REPORTS%\summary.html

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
for %%A in (%*) do (
  if /I "%%A"=="--headed" set PYTEST_HEADED=1
  rem Suporta formato --step-delay=0.7
  echo %%A | findstr /I /B /C:"--step-delay=" >nul && set STEP_DELAY_OPT=%%A
)

if defined STEP_DELAY_OPT (
  set ARGS=%ARGS% %STEP_DELAY_OPT%
)

echo Executando: pytest %ARGS% (PYTEST_HEADED=%PYTEST_HEADED%)
"%VENV%\Scripts\python.exe" -m pytest %ARGS%
if errorlevel 1 (
  echo Pytest retornou erro. Ainda assim, gerando resumo e abrindo HTML...
)

REM Gerar resumo HTML com suite/casos, resultados e screenshots via PowerShell inline
powershell -NoProfile -ExecutionPolicy Bypass -Command "^$ErrorActionPreference='Stop'; [xml]^$x=Get-Content -LiteralPath '%JUNIT%'; ^$cases=@(); foreach(^$suite in ^$x.testsuites.testsuite){ foreach(^$tc in ^$suite.testcase){ ^$status='passed'; if(^$tc.failure){^$status='failed'} elseif(^$tc.error){^$status='error'} elseif(^$tc.skipped){^$status='skipped'}; ^$cases+= [pscustomobject]@{ suite=^$suite.name; name=^$tc.name; classname=^$tc.classname; status=^$status } } } ; ^$shots=Get-ChildItem -LiteralPath '%SCREENSHOTS%' -Filter *.png -ErrorAction SilentlyContinue ^| Sort-Object Name; ^$h=@(); ^$h+= '<!DOCTYPE html><html><head><meta charset=\"utf-8\"/><title>Resumo E2E</title><style>body{font-family:Segoe UI,Arial} .ok{color:#2e7d32} .fail{color:#c62828} table{border-collapse:collapse;width:100%} th,td{border:1px solid #ddd;padding:8px} img{max-width:640px;border:1px solid #ccc;margin:6px}</style></head><body>'; ^$h+= '<h1>Resumo dos Testes E2E</h1>'; ^$h+= ('<p><strong>Relatório pytest.html:</strong> <a href=\"' + (Resolve-Path '%HTML_REPORT%') + '\" target=\"_blank\">Abrir</a></p>'); ^$h+= '<h2>Casos de Teste</h2><table><tr><th>Suite</th><th>Classe</th><th>Teste</th><th>Status</th></tr>'; foreach(^$c in ^$cases){ ^$cls= if(^$c.status -eq 'passed'){'ok'}else{'fail'}; ^$h+= ('<tr><td>' + ^$c.suite + '</td><td>' + ^$c.classname + '</td><td>' + ^$c.name + '</td><td class=\"' + ^$cls + '\">' + ^$c.status + '</td></tr>') }; ^$h+= '</table>'; ^$h+= '<h2>Screenshots</h2>'; foreach(^$f in ^$shots){ ^$h+= ('<div><p>' + ^$f.Name + '</p><img src=\"' + ^$f.FullName + '\" alt=\"' + ^$f.Name + '\"/></div>') }; ^$h+= '</body></html>'; Set-Content -LiteralPath '%SUMMARY%' -Value (^$h -join '') -Encoding UTF8; Write-Host ('Resumo gerado em: ' + (Resolve-Path '%SUMMARY%'))"

REM Abrir relatório HTML padrão do pytest
powershell -NoProfile -Command "Invoke-Item (Resolve-Path '%HTML_REPORT%')"

REM Opcional: abrir resumo
REM powershell -NoProfile -Command "Invoke-Item (Resolve-Path '%SUMMARY%')"

exit /b 0