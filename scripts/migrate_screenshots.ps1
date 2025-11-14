param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..'))
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[Migrate] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Warning "[Migrate] $m" }
function Write-Err($m){ Write-Host "[Migrate] $m" -ForegroundColor Red }

$src = Join-Path $Root 'reports\screenshots'
$dst = Join-Path $Root 'screenshots'

Write-Info "Origem: $src"
Write-Info "Destino: $dst"

if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }

if (-not (Test-Path -LiteralPath $src)) {
  Write-Warn "Diretório de origem não existe. Nada a migrar."
  exit 0
}

# Remover pasta _invalid por solicitação
$invalid = Join-Path $src '_invalid'
if (Test-Path -LiteralPath $invalid) {
  try { Remove-Item -LiteralPath $invalid -Recurse -Force; Write-Info "Removida pasta _invalid." } catch { Write-Warn "Falha ao remover _invalid: $($_.Exception.Message)" }
}

# Mover todos os arquivos de imagem, mantendo estrutura relativa
$files = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue
if (-not $files -or $files.Count -eq 0) { Write-Warn 'Nenhum arquivo de imagem para migrar.'; exit 0 }

$moved = 0
foreach($f in $files){
  $rel = (Resolve-Path -LiteralPath $f.FullName).Path.Substring($src.Length) -replace '^[\\/]+' , ''
  $target = Join-Path $dst $rel
  $targetDir = Split-Path -Parent $target
  if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
  Write-Info "Movendo: $($f.FullName) -> $target"
  Move-Item -LiteralPath $f.FullName -Destination $target -Force
  $moved += 1
}

Write-Info ("Arquivos movidos: {0}" -f $moved)

# Verificação simples: não restam imagens na origem
$remaining = Get-ChildItem -LiteralPath $src -Recurse -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue
if ($remaining -and $remaining.Count -gt 0) {
  Write-Warn ("Restam {0} arquivo(s) na origem após migração." -f $remaining.Count)
} else {
  Write-Info "Origem sem imagens após migração."
}

Write-Info "Migração concluída."