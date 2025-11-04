param(
    [string]$Marker,
    [string]$JUnitXml,
    [string]$ExtraPytestArgs,
    [switch]$Headed
)

$ErrorActionPreference = 'Stop'

function Ensure-Python {
    if (Get-Command python -ErrorAction SilentlyContinue) { return }
    Write-Host "Python não encontrado. Tentando instalar via winget..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Python.Python.3.11 --source winget --accept-source-agreements --accept-package-agreements
    } else {
        throw "winget não disponível. Instale Python manualmente (https://www.python.org/downloads/)"
    }
}

function Ensure-Venv {
    param([string]$Root)
    $venvPath = Join-Path $Root '.venv'
    if (-not (Test-Path $venvPath)) {
        Write-Host "Criando venv em $venvPath" -ForegroundColor Cyan
        python -m venv $venvPath
    }
    return $venvPath
}

function Install-Dependencies {
    param([string]$VenvPath, [string]$Root)
    $pipExe = Join-Path $VenvPath 'Scripts\pip.exe'
    $reqFile = Join-Path $Root 'requirements.txt'
    & $pipExe install --upgrade pip
    & $pipExe install -r $reqFile
}

function Run-Tests {
    param([string]$VenvPath, [string]$Root, [string]$Marker, [string]$JUnitXml, [string]$ExtraPytestArgs, [bool]$Headed)
    $pythonExe = Join-Path $VenvPath 'Scripts\python.exe'
    $pytestArgs = @()

    if ($Marker) { $pytestArgs += @('-m', $Marker) }

    if ($JUnitXml) {
        $reportDir = Split-Path -Parent $JUnitXml
        if ($reportDir -and -not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
        $pytestArgs += @('--junitxml', $JUnitXml)
    }

    if ($ExtraPytestArgs) { $pytestArgs += ($ExtraPytestArgs -split '\s+') }
    if ($Headed) { $pytestArgs += '--headed' }

    $pytestArgs += '-q'

    Write-Host "Executando: pytest $($pytestArgs -join ' ')" -ForegroundColor Green
    & $pythonExe -m pytest @pytestArgs
}

try {
    $Root = Resolve-Path (Join-Path $PSScriptRoot '..')
    Ensure-Python
    $venvPath = Ensure-Venv -Root $Root
    Install-Dependencies -VenvPath $venvPath -Root $Root
    Run-Tests -VenvPath $venvPath -Root $Root -Marker $Marker -JUnitXml $JUnitXml -ExtraPytestArgs $ExtraPytestArgs -Headed $Headed.IsPresent
}
catch {
    Write-Error $_
    exit 1
}