param(
    [Parameter(Mandatory=$false)]
    [string]$ScreenshotsDir
)

# Comentário (PT-BR): Se não for informado, usar caminho padrão relativo
if (-not $ScreenshotsDir -or $ScreenshotsDir.Trim() -eq "") {
    $ScreenshotsDir = Join-Path $PSScriptRoot "..\reports\screenshots"
    Write-Host "[Cleanup] ScreenshotsDir não informado; usando padrão: $ScreenshotsDir"
}

# Comentário (PT-BR): Este script remove arquivos .png da pasta de screenshots
# após a execução dos testes. Ele valida existência, trata erros por arquivo,
# confirma remoção e registra logs detalhados para rastreamento.

Write-Host "[Cleanup] Iniciando limpeza de screenshots em: $ScreenshotsDir"

try {
    if (-not (Test-Path -LiteralPath $ScreenshotsDir)) {
        Write-Warning "[Cleanup] Diretório de screenshots não existe: $ScreenshotsDir"
        return
    }

    $files = Get-ChildItem -LiteralPath $ScreenshotsDir -Filter *.png -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) {
        Write-Host "[Cleanup] Nenhum arquivo .png encontrado para remoção."
        return
    }

    Write-Host ("[Cleanup] Encontrados {0} arquivo(s) .png." -f $files.Count)

    $removed = 0
    foreach ($f in $files) {
        Write-Host ("[Cleanup] Removendo: {0}" -f $f.FullName)
        try {
            # Comentário (PT-BR): Remove o arquivo e força parada em caso de erro
            Remove-Item -LiteralPath $f.FullName -ErrorAction Stop
            # Confirma se foi removido
            if (-not (Test-Path -LiteralPath $f.FullName)) {
                Write-Host ("[Cleanup] Remoção confirmada: {0}" -f $f.Name)
                $removed += 1
            } else {
                Write-Warning ("[Cleanup] Arquivo persiste após remoção: {0}" -f $f.Name)
            }
        } catch {
            Write-Error ("[Cleanup] Falha ao remover {0}: {1}" -f $f.Name, $_.Exception.Message)
        }
    }

    # Resumo final com checagem dos remanescentes
    $remaining = Get-ChildItem -LiteralPath $ScreenshotsDir -Filter *.png -ErrorAction SilentlyContinue
    $remainingCount = if ($remaining) { $remaining.Count } else { 0 }
    Write-Host ("[Cleanup] Removidos {0} arquivo(s). Restante(s): {1}." -f $removed, $remainingCount)
} catch {
    Write-Error ("[Cleanup] Erro inesperado na limpeza: {0}" -f $_.Exception.Message)
}

Write-Host "[Cleanup] Concluído."