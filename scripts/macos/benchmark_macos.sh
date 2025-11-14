#!/usr/bin/env bash
set -euo pipefail

# Benchmark simples de compatibilidade e desempenho no macOS
# Executa 3 iterações headless e registra tempos

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/benchmark_macos_$(date +%Y%m%d_%H%M%S).log"

echo "[macOS] Benchmark iniciando (3 iterações headless)" | tee -a "$LOG_FILE"

ITER=1
while [ $ITER -le 3 ]; do
  START_TS=$(date +%s)
  "$(dirname "$0")/run_local_macos.sh" || true
  END_TS=$(date +%s)
  DUR=$((END_TS-START_TS))
  echo "[macOS] Iteração $ITER concluída em ${DUR}s" | tee -a "$LOG_FILE"
  ITER=$((ITER+1))
done

echo "[macOS] Benchmark finalizado. Veja '$LOG_FILE' para detalhes."