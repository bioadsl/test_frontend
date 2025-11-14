param(
    [switch]$KeepScreens,
    [int]$StepDelayMs = 1200,
    [int]$ScreenshotDelayMs = 800
)

$ErrorActionPreference = 'Stop'

function Ensure-Venv {
    param([string]$Root)
    $venvPath = Join-Path $Root '.venv'
    $pythonExe = Join-Path $venvPath 'Scripts\python.exe'
    if (-not (Test-Path $pythonExe)) {
        Write-Host "Criando venv em '$venvPath'" -ForegroundColor Cyan
        py -3 -m venv $venvPath
    }
    return $venvPath
}

function Install-Dependencies {
    param([string]$VenvPath, [string]$Root)
    $pythonExe = Join-Path $VenvPath 'Scripts\python.exe'
    $pipExe = Join-Path $VenvPath 'Scripts\pip.exe'
    & $pythonExe -m pip install -U pip | Out-Host
    & $pipExe install -r (Join-Path $Root 'requirements.txt') | Out-Host
}

function Run-Demo {
    param([string]$VenvPath, [string]$Root, [switch]$KeepScreens, [int]$StepDelayMs, [int]$ScreenshotDelayMs)
    $pythonExe = Join-Path $VenvPath 'Scripts\python.exe'
    $reportsDir = Join-Path $Root 'reports'
    $screensDir = Join-Path $Root 'screenshots'
    $legacyScreensDir = Join-Path $reportsDir 'screenshots'
    if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
    if (-not (Test-Path $screensDir)) { New-Item -ItemType Directory -Path $screensDir -Force | Out-Null }

    # Normalização: evitar diretório duplicado em reports\screenshots
    if (Test-Path -LiteralPath $legacyScreensDir) {
        Write-Host "Detectado diretório legado: '$legacyScreensDir'. Normalizando para '$screensDir'" -ForegroundColor Yellow
        try {
            $legacyFiles = Get-ChildItem -LiteralPath $legacyScreensDir -Recurse -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue
            if ($legacyFiles -and $legacyFiles.Count -gt 0) {
                # Migrar quaisquer imagens para a pasta raiz de screenshots
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\migrate_screenshots.ps1') -Root $Root
            }
            # Remover diretório vazio após migração para evitar duplicidade visual
            $remaining = Get-ChildItem -LiteralPath $legacyScreensDir -Force -ErrorAction SilentlyContinue
            if (-not $remaining -or $remaining.Count -eq 0) {
                Remove-Item -LiteralPath $legacyScreensDir -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Diretório legado removido: '$legacyScreensDir'" -ForegroundColor Yellow
            }
        } catch {
            Write-Warning ("Falha ao normalizar diretório de screenshots legado: {0}" -f $_.Exception.Message)
        }
    }

    $env:PYTEST_HEADED = '1'
    $env:STEP_DELAY_MS = [string]$StepDelayMs
    $env:SCREENSHOT_DELAY_MS = [string]$ScreenshotDelayMs

    $junit = Join-Path $reportsDir 'junit.xml'
    $html = Join-Path $reportsDir 'pytest.html'
    $testsDir = Join-Path $Root 'tests'

    $args = @('-m','e2e','--junitxml',$junit,'--html',$html,'--self-contained-html','-q',$testsDir)

    Write-Host "Executando: pytest $($args -join ' ') (PYTEST_HEADED=$env:PYTEST_HEADED STEP_DELAY_MS=$env:STEP_DELAY_MS SCREENSHOT_DELAY_MS=$env:SCREENSHOT_DELAY_MS)" -ForegroundColor Green
    & $pythonExe -m pytest @args

    # Gerar índice de screenshots para consumo por results.html/cases.html
    try {
        $indexPath = Join-Path $screensDir 'index.json'
        Write-Host "Gerando índice de screenshots em '$indexPath'" -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\generate_index_json.ps1') -ScreenshotsDir $screensDir -OutputPath $indexPath
    } catch {
        Write-Warning ("Falha ao gerar index.json de screenshots: {0}" -f $_.Exception.Message)
    }

    $results = Join-Path $reportsDir 'results.html'
    if (-not (Test-Path $results)) { $results = $html }
    if (Test-Path $results) {
        Write-Host "Abrindo relatório: $results" -ForegroundColor Cyan
        try { Invoke-Item $results } catch { Write-Warning "Falha ao abrir relatório: $($_.Exception.Message)" }
    }

    if (-not $KeepScreens.IsPresent) {
        Write-Host "Executando cleanup de screenshots em '$screensDir'" -ForegroundColor Yellow
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\cleanup_screens.ps1') -ScreenshotsDir $screensDir
    } else {
        Write-Host "Mantendo screenshots desta execução (switch -KeepScreens)." -ForegroundColor Yellow
    }
}

try {
    $Root = Resolve-Path (Join-Path $PSScriptRoot '..')
    $venvPath = Ensure-Venv -Root $Root
    Install-Dependencies -VenvPath $venvPath -Root $Root
    Run-Demo -VenvPath $venvPath -Root $Root -KeepScreens:$KeepScreens.IsPresent -StepDelayMs $StepDelayMs -ScreenshotDelayMs $ScreenshotDelayMs
}
catch {
    Write-Error $_
    exit 1
}
exit 0