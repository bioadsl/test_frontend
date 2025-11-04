#!/usr/bin/env bash
set -euo pipefail

MARKER=""
JUNITXML=""
EXTRA_ARGS=""
HEADED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --marker)
      MARKER="$2"; shift 2;;
    --junitxml)
      JUNITXML="$2"; shift 2;;
    --extra-args)
      EXTRA_ARGS="$2"; shift 2;;
    --headed)
      HEADED=true; shift 1;;
    --help|-h)
      echo "Uso: $0 [--marker e2e] [--junitxml reports/junit.xml] [--extra-args \"-k expr -x\"]";
      exit 0;;
    *)
      echo "Argumento desconhecido: $1"; exit 1;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"

PYTHON_BIN="python3"
if ! command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

if [[ ! -d "$VENV_DIR" ]]; then
  echo "Criando venv em $VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

PIP_BIN="$VENV_DIR/bin/pip"
PYTHON_VENV_BIN="$VENV_DIR/bin/python"

"$PIP_BIN" install --upgrade pip
"$PIP_BIN" install -r "$ROOT_DIR/requirements.txt"

ARGS=("-q")
if [[ -n "$MARKER" ]]; then
  ARGS+=("-m" "$MARKER")
fi

if [[ -n "$JUNITXML" ]]; then
  mkdir -p "$(dirname "$JUNITXML")"
  ARGS+=("--junitxml" "$JUNITXML")
fi

if [[ -n "$EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARR=($EXTRA_ARGS)
  ARGS+=("${EXTRA_ARR[@]}")
fi

if [[ "$HEADED" == "true" ]]; then
  ARGS+=("--headed")
fi

echo "Executando: pytest ${ARGS[*]}"
"$PYTHON_VENV_BIN" -m pytest "${ARGS[@]}"