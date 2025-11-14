#!/usr/bin/env bash
set -euo pipefail

# Executa testes E2E localmente no macOS com headless por padrão
# Uso: run_local_macos.sh [--headed] [--keep-screens]

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REPORTS_DIR="$ROOT_DIR/reports"
SCREENS_DIR="$ROOT_DIR/screenshots"

HEADED=0
KEEP_SCREENS=0
for arg in "$@"; do
  case "$arg" in
    --headed) HEADED=1 ;;
    --keep-screens) KEEP_SCREENS=1 ;;
  esac
done

mkdir -p "$REPORTS_DIR" "$SCREENS_DIR"

if [ ! -d "$VENV_DIR" ]; then
  echo "[macOS] venv não encontrado. Inicializando via setup_macos.sh..."
  "$(dirname "$0")/setup_macos.sh"
fi

source "$VENV_DIR/bin/activate"

# Delays amigáveis para estabilidade visual / screenshots
export STEP_DELAY_MS="1200"
export SCREENSHOT_DELAY_MS="800"
if [ "$HEADED" -eq 1 ]; then
  export PYTEST_HEADED="1"
else
  export PYTEST_HEADED=""
fi

echo "[macOS] Executando testes (headed=$HEADED)"
pytest -m e2e \
  --junitxml "$REPORTS_DIR/junit.xml" \
  --html "$REPORTS_DIR/pytest.html" --self-contained-html \
  --cov=. --cov-report=xml:"$REPORTS_DIR/coverage.xml" --cov-report=term \
  -q "$ROOT_DIR/tests"

HTML_REPORT="$REPORTS_DIR/pytest.html"
if [ -f "$HTML_REPORT" ]; then
  echo "[macOS] Abrindo relatório em '$HTML_REPORT'"
  open "$HTML_REPORT" || true
fi

if [ "$KEEP_SCREENS" -eq 0 ]; then
  echo "[macOS] Limpando screenshots antigos em '$SCREENS_DIR'"
  find "$SCREENS_DIR" -type f -name '*.png' -delete || true
else
  echo "[macOS] Mantendo screenshots desta execução."
fi

echo "[macOS] Execução concluída com sucesso."