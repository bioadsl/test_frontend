@echo off
setlocal enabledelayedexpansion

REM GitHub Actions Workflow Runner (Windows .bat)
REM Features:
REM - Environment checks (Git, GitHub CLI)
REM - Secure auth via GH_TOKEN (no token printed/logged)
REM - Trigger workflow and capture run ID/URL
REM - Poll status and show final conclusion
REM - Error handling (network, credentials, workflow not found)
REM - Detailed logs to file
REM - Options for manual params, Task Scheduler registration, CI-friendly flags

REM --------------------------- Defaults ---------------------------
set OWNER=bioadsl
set REPO=test_frontend
set WORKFLOW=E2E Tests
set REF=main
set INPUTS_FILE=
set WAIT=true
set TIMEOUT_SEC=900
set GH_HOST=github.com
set REGISTER_TASK=
set TASK_NAME=
set TASK_TIME=
set CI_MODE=false
set PUSH=true

REM Paths and logging
set ROOT=%~dp0..
if not exist "%ROOT%" set ROOT=%~dp0.
set LOG_DIR=%ROOT%\logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
set LOG_FILE=%LOG_DIR%\gh_actions_latest.log

REM --------------------------- Helpers ---------------------------
goto :after_helpers

:log
setlocal
set MSG=%*
echo [%date% %time%] %MSG%
>> "%LOG_FILE%" echo [%date% %time%] %MSG%
endlocal
goto :eof

:usage
echo.
echo Usage: %~nx0 [--owner bioadsl] [--repo test_frontend] [--workflow ci.yml] [options]
echo.
echo Parâmetros (opcionais; padrões entre colchetes):
echo   --owner ^<org^>             GitHub owner/organization [bioadsl]
echo   --repo ^<repo^>             GitHub repository name [test_frontend]
echo   --workflow ^<file_or_name^> Workflow file or name [ci.yml]
echo.
echo Optional:
echo   --ref ^<branch/tag/sha^>    Git ref to run on (default: main)
echo   --inputs-file ^<path.json^> JSON of workflow_dispatch inputs
echo   --wait                      Wait until completion and exit with conclusion
echo   --timeout-sec ^<N^>         Max seconds to wait (default: 900)
echo   --gh-host ^<host^>          GitHub host (default: github.com)
echo   --ci                        CI-friendly: non-interactive, requires GH_TOKEN
echo   --no-push                   Do not commit/push local changes before triggering
echo   --register-task             Register daily Task Scheduler job
echo   --task-name ^<name^>        Task name (used with --register-task)
echo   --task-time ^<HH:MM^>       Start time (24h) for scheduled task
echo   --help                      Show this help
echo.
echo Exemplos:
echo   %~nx0 --wait
echo   %~nx0 --ref main --wait --timeout-sec 600
echo   %~nx0 --owner bioadsl --repo test_frontend --workflow ci.yml --ref main --wait
echo   %~nx0 --wait --no-push
echo.
echo Security:
echo   Set GH_TOKEN as an environment variable (PAT with repo scope); the script
echo   uses it implicitly for gh commands. Token is never printed nor logged.
echo.
exit /b 2

:ensure_prog
REM %1 = exe name, %2 = friendly name, %3 = winget id
where %1 >nul 2>nul
if not errorlevel 1 goto :eof
call :log "%2 not found. Attempting install via winget..."
where winget >nul 2>nul || (call :log "winget not available. Please install %2 manually." & exit /b 1)
winget install -e --id %3 --source winget --accept-source-agreements --accept-package-agreements >> "%LOG_FILE%" 2>&1
if errorlevel 1 (call :log "Failed to install %2 via winget." & exit /b 1)
goto :eof

:ensure_gh_path
REM Tenta localizar gh.exe em caminhos comuns e adiciona ao PATH desta sessão
set GH_EXE1=%ProgramFiles%\GitHub CLI\gh.exe
set GH_EXE2=%LOCALAPPDATA%\Programs\gh\bin\gh.exe
set GH_DIR=
if exist "%GH_EXE1%" set GH_DIR=%ProgramFiles%\GitHub CLI
if not defined GH_DIR if exist "%GH_EXE2%" set GH_DIR=%LOCALAPPDATA%\Programs\gh\bin
if defined GH_DIR (
  set "PATH=%PATH%;%GH_DIR%"
  call :log "Added GitHub CLI to PATH: %GH_DIR%"
) else (
  call :log "gh.exe not found in common locations."
)
goto :eof

:parse_json_to_inputs
REM %1 = JSON path, outputs INPUT_ARGS variable with -f key=value pairs
set INPUT_ARGS=
if not exist "%~1" (call :log "Inputs file not found: %~1" & exit /b 1)
for /f "usebackq delims=" %%X in (`powershell -NoProfile -Command ^
  "$j=Get-Content -Raw '%~1' ^| ConvertFrom-Json; ^
   $o=@(); foreach($p in $j.PSObject.Properties){ $o += ('-f', \"'\" + $p.Name + '=' + ($p.Value) + \"'\"); }; ^
   $o -join ' '"`) do set INPUT_ARGS=%%X
goto :eof

:after_helpers

REM --------------------------- Push local changes (optional) ---------------------------
:push_changes
setlocal
rem Detect current branch
for /f "usebackq delims=" %%B in (`git rev-parse --abbrev-ref HEAD 2^>nul`) do set CUR_BRANCH=%%B
if not defined CUR_BRANCH (
  call :log "Unable to determine current branch. Skipping push."
  endlocal & goto :eof
)
call :log "Current branch: %CUR_BRANCH%"

rem Check remote origin
git remote get-url origin >nul 2>nul
if errorlevel 1 (
  call :log "Remote 'origin' not set. Expected https://github.com/%OWNER%/%REPO%.git"
  endlocal & goto :eof
)

rem Stage changes excluding transient artifacts
call :log "Staging changes (excluding reports/, logs/, .venv/, .pytest_cache/)..."
git add -A -- . ":(exclude)reports/" ":(exclude)logs/" ":(exclude).venv/" ":(exclude).pytest_cache/"

rem Commit if there are staged changes
for /f "usebackq delims=" %%S in (`git diff --cached --name-only`) do set HAS_STAGED=1
if not defined HAS_STAGED (
  call :log "No staged changes to commit. Skipping commit/push."
  endlocal & goto :eof
)

for /f "usebackq tokens=*" %%t in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) do set TS=%%t
git commit -m "chore(ci): push local changes before Actions (%TS%)" >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "Commit failed. Check git status."
  endlocal & exit /b 1
)

rem Push safely
call :log "Pushing to origin %CUR_BRANCH%..."
git push origin %CUR_BRANCH% >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "Push failed. Try setting upstream: git push -u origin %CUR_BRANCH%"
  endlocal & exit /b 1
)
call :log "Push completed."
endlocal
goto :eof

REM --------------------------- Parse args ---------------------------
if "%~1"=="--help" goto usage
set ARGS=%*
:parse_loop
if "%~1"=="" goto args_done
if /I "%~1"=="--owner"         set OWNER=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--repo"          set REPO=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--workflow"      set WORKFLOW=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--ref"           set REF=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--inputs-file"   set INPUTS_FILE=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--wait"          set WAIT=true& shift& goto parse_loop
if /I "%~1"=="--timeout-sec"   set TIMEOUT_SEC=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--gh-host"       set GH_HOST=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--ci"            set CI_MODE=true& shift& goto parse_loop
if /I "%~1"=="--no-push"       set PUSH=false& shift& goto parse_loop
if /I "%~1"=="--register-task" set REGISTER_TASK=true& shift& goto parse_loop
if /I "%~1"=="--task-name"     set TASK_NAME=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--task-time"     set TASK_TIME=%~2& shift& shift& goto parse_loop
if /I "%~1"=="--help"          goto usage
call :log "Unknown argument: %~1" & goto usage
:args_done

if not defined OWNER (call :log "Missing --owner" & goto usage)
if not defined REPO (call :log "Missing --repo" & goto usage)
if not defined WORKFLOW (call :log "Missing --workflow" & goto usage)

REM If CI mode or GH_TOKEN is provided, prefer API fallback regardless of gh presence
if /I "%CI_MODE%"=="true" set USE_API_FALLBACK=1
if defined GH_TOKEN set USE_API_FALLBACK=1

REM --------------------------- Optional: Register Task ---------------------------
if /I "%REGISTER_TASK%"=="true" goto schedule_task

REM --------------------------- Initialize timestamped log ---------------------------
powershell -NoProfile -Command "(Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')" > "%LOG_DIR%\__ts__.txt" 2>nul
set /p TS=<"%LOG_DIR%\__ts__.txt"
del "%LOG_DIR%\__ts__.txt" >nul 2>nul
set LOG_FILE=%LOG_DIR%\gh_actions_%TS%.log

REM --------------------------- Env checks ---------------------------
call :log "Checking environment (Git, GitHub CLI)..."
call :ensure_prog git "Git" Git.Git || exit /b 1
REM Tentar usar GitHub CLI; se indisponível, preparar fallback via API
where gh >nul 2>nul
if errorlevel 1 (
  call :log "GitHub CLI not found. Attempting install via winget..."
  where winget >nul 2>nul && (
    winget install -e --id GitHub.cli --source winget --accept-source-agreements --accept-package-agreements >> "%LOG_FILE%" 2>&1
  )
  call :ensure_gh_path
  where gh >nul 2>nul
  if errorlevel 1 (
    call :log "GitHub CLI still unavailable; switching to API fallback (requires GH_TOKEN)."
    set USE_API_FALLBACK=1
  )
) else (
  REM gh disponível; manter USE_API_FALLBACK como está (pode ter sido forçado por --ci ou GH_TOKEN)
)

REM --------------------------- Network check ---------------------------
ping -n 1 %GH_HOST% >nul 2>nul
if errorlevel 1 (call :log "Network check failed: cannot reach %GH_HOST%" & exit /b 1)

REM --------------------------- Auth ---------------------------
call :log "Validating GitHub auth..."
if defined USE_API_FALLBACK (
  if not defined GH_TOKEN (call :log "API fallback requires GH_TOKEN environment variable." & exit /b 1)
  call :log "Using API fallback with GH_TOKEN for authentication."
) else (
  if "%CI_MODE%"=="true" if not defined GH_TOKEN (call :log "CI mode requires GH_TOKEN environment variable." & exit /b 1)
  gh auth status -h %GH_HOST% >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    if defined GH_TOKEN (
      REM Rely on ephemeral GH_TOKEN (no login or storage)
      call :log "Using GH_TOKEN from environment for authentication (ephemeral)."
    ) else (
      call :log "Not authenticated. Please run 'gh auth login' interactively (browser) or set GH_TOKEN."
      exit /b 1
    )
  )
)

REM --------------------------- Optional push ---------------------------
if /I "%PUSH%"=="true" (
  call :log "Attempting to push local changes before triggering Actions..."
  call :push_changes || (call :log "Push step failed; continuing to trigger Actions anyway.")
)

REM --------------------------- Workflow validation ---------------------------
if defined USE_API_FALLBACK goto api_validate
call :log "Validating workflow '%WORKFLOW%' on %OWNER%/%REPO%..."
gh workflow view "%WORKFLOW%" -R %OWNER%/%REPO% --json name,path,id --jq .name >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "Workflow not found by name/file. Listing available workflows..."
  gh workflow list -R %OWNER%/%REPO% >> "%LOG_FILE%" 2>&1
  rem Fallback: pick the first workflow ID via JSON to avoid formatting issues
  for /f "usebackq delims=" %%I in (`gh workflow list -R %OWNER%/%REPO% --json "id" --jq ".[0].id"`) do set WF_ID=%%I
  if defined WF_ID (
    call :log "Using first active workflow ID: !WF_ID! (override default)."
    set WORKFLOW=!WF_ID!
  ) else (
    call :log "ERROR: Unable to resolve workflow; please pass --workflow <name|id>."
    exit /b 1
  )
)

REM --------------------------- Inputs (optional) ---------------------------
set INPUT_ARGS=
if defined INPUTS_FILE (
  call :log "Parsing inputs from JSON: %INPUTS_FILE%"
  call :parse_json_to_inputs "%INPUTS_FILE%" || (call :log "Failed to parse inputs JSON." & exit /b 1)
)

REM --------------------------- Trigger run ---------------------------
if defined USE_API_FALLBACK goto trigger_run_api
call :log "Triggering workflow run on ref '%REF%'..."
gh workflow run "%WORKFLOW%" -R %OWNER%/%REPO% --ref "%REF%" %INPUT_ARGS% >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  call :log "Failed to trigger workflow run. Check credentials, permissions, and inputs."
  exit /b 1
)

REM --------------------------- Locate run ID ---------------------------
for /f "usebackq delims=" %%I in (`gh run list -R %OWNER%/%REPO% --workflow "%WORKFLOW%" --branch "%REF%" --limit 1 --json databaseId,url,status --jq ".[0].databaseId"`) do set RUN_ID=%%I
if not defined RUN_ID (
  call :log "Unable to determine run ID."
  exit /b 1
)
for /f "usebackq delims=" %%U in (`gh run view !RUN_ID! -R %OWNER%/%REPO% --json htmlUrl --jq .htmlUrl`) do set RUN_URL=%%U
call :log "Run created: ID=!RUN_ID! URL=!RUN_URL!"
echo Run URL: !RUN_URL!

REM --------------------------- Optionally wait ---------------------------
if /I "%WAIT%"=="true" (
  call :log "Watching run until completion..."
  gh run watch !RUN_ID! -R %OWNER%/%REPO% --exit-status >> "%LOG_FILE%" 2>&1
  if errorlevel 1 (
    call :log "Workflow completed with failure or was cancelled."
    exit /b 1
  ) else (
    call :log "Workflow completed successfully."
    exit /b 0
  )
)

REM No wait: exit success after trigger
exit /b 0

REM --------------------------- API Fallback: Resolve and trigger in one call ---------------------------
:api_validate
call :log "Triggering workflow via API on %OWNER%/%REPO% ref '%REF%'..."
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $owner='%OWNER%'; $repo='%REPO%'; $wf='%WORKFLOW%'; $ref='%REF%'; $token=$env:GH_TOKEN; if([string]::IsNullOrWhiteSpace($token)){ throw 'GH_TOKEN is required for API fallback' }; $headers=@{ Authorization='Bearer '+$token; Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28' }; $list=Invoke-RestMethod -Uri \"https://api.github.com/repos/$owner/$repo/actions/workflows\" -Headers $headers -Method Get; $wfId=$null; if($wf -match '^[0-9]+$'){ $wfId=[int]$wf } elseif($wf.ToLower().EndsWith('.yml')){ $wfLower=$wf.ToLower(); $wfId = ($list.workflows | Where-Object { $_.path.ToLower() -eq $wfLower -or $_.path.ToLower().EndsWith('/'+$wfLower) }).id } else { $wfId = ($list.workflows | Where-Object { $_.name -eq $wf }).id }; if(-not $wfId){ throw \"Workflow not found by name/path/id: $wf\" }; $body=@{ ref=$ref }; $inputsFile=$env:INPUTS_FILE; if($inputsFile -and (Test-Path $inputsFile)) { $inputs = Get-Content -Raw $inputsFile | ConvertFrom-Json; $body.inputs = $inputs }; $json = $body | ConvertTo-Json -Depth 5; Invoke-RestMethod -Uri \"https://api.github.com/repos/$owner/$repo/actions/workflows/$wfId/dispatches\" -Headers $headers -Method Post -Body $json -ContentType 'application/json'; Write-Output ('Run URL: https://github.com/'+$owner+'/'+$repo+'/actions/workflows/'+$wfId)" >> "%LOG_FILE%" 2>&1
for /f "usebackq delims=" %%U in ("%LOG_FILE%") do (
  echo %%U | findstr /C:"Run URL:" >nul && echo %%U
)
if /I "%WAIT%"=="true" (
  call :log "API fallback does not implement watch; open the run URL to view status."
)
exit /b 0

REM --------------------------- Task Scheduler ---------------------------
:schedule_task
if not defined TASK_NAME (call :log "--register-task requires --task-name" & exit /b 1)
if not defined TASK_TIME (call :log "--register-task requires --task-time (HH:MM)" & exit /b 1)
set THIS=%~f0
set CMD="%THIS%" --owner %OWNER% --repo %REPO% --workflow "%WORKFLOW%" --ref "%REF%" --wait --timeout-sec %TIMEOUT_SEC%
schtasks /Create /SC DAILY /ST %TASK_TIME% /TN "%TASK_NAME%" /TR %CMD% /F >> "%LOG_FILE%" 2>&1
if errorlevel 1 (call :log "Failed to register scheduled task." & exit /b 1)
call :log "Scheduled task '%TASK_NAME%' created for %TASK_TIME%."
exit /b 0