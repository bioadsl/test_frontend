param(
  [string]$ScreenshotsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\\screenshots')),
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host "[Index] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Warning "[Index] $m" }
function Write-Err($m){ Write-Host "[Index] $m" -ForegroundColor Red }

try {
  if (-not $OutputPath -or $OutputPath.Trim() -eq '') {
    $OutputPath = Join-Path $ScreenshotsDir 'index.json'
  }
  if (-not (Test-Path -LiteralPath $ScreenshotsDir)) {
    Write-Warn "Diretório de screenshots inexistente: $ScreenshotsDir"
    exit 0
  }
  $files = Get-ChildItem -LiteralPath $ScreenshotsDir -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue
  if (-not $files -or $files.Count -eq 0) {
    Write-Info 'Nenhuma imagem encontrada; gravando lista vazia.'
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutputPath, '[]', $utf8NoBom)
    exit 0
  }

  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

  $list = @()
  foreach($f in $files){
    $w = $null; $h = $null
    try {
      $img = [System.Drawing.Image]::FromFile($f.FullName)
      $w = [int]$img.Width; $h = [int]$img.Height
      $img.Dispose()
    } catch { $w = $null; $h = $null }
    $rel = $f.Name
    $sec = 'unknown'
    if ($rel -match '_step_') { $sec = 'step' }
    elseif ($rel -match '_end_') { $sec = 'end' }
    elseif ($rel -match '_fail_') { $sec = 'fail' }
    $item = [pscustomobject]@{
      file = $rel
      original = $rel
      section = $sec
      timestamp = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
      width = $w
      height = $h
      valid = $true
    }
    $list += $item
  }
  # Ordena por nome para consistência
  $list = $list | Sort-Object file
  $json = $list | ConvertTo-Json -Depth 4
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)
  Write-Info ("Gerado {0} com {1} itens" -f $OutputPath, $list.Count)
} catch {
  Write-Err ("Falha ao gerar index.json: {0}" -f $_.Exception.Message)
  exit 1
}
exit 0