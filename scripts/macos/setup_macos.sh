#!/usr/bin/env bash
set -euo pipefail

# Setup do ambiente de desenvolvimento para macOS
# - Verifica Homebrew (opcional)
# - Instala Google Chrome (opcional)
# - Prepara venv Python e instala dependências

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"

echo "[macOS] Preparando ambiente em: $ROOT_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERRO] python3 não encontrado. Instale via Xcode Command Line Tools ou Homebrew."
  echo "        Exemplo: xcode-select --install  (ou)  brew install python@3.11"
  exit 1
fi

if command -v brew >/dev/null 2>&1; then
  echo "[macOS] Homebrew detectado. Você pode instalar Google Chrome com:"
  echo "        brew install --cask google-chrome"
else
  echo "[macOS] Homebrew NÃO detectado. Caso queira instalar Chrome facilmente, instale o Homebrew:"
  echo "        /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi

mkdir -p "$ROOT_DIR/reports" "$ROOT_DIR/screenshots"

if [ ! -d "$VENV_DIR" ]; then
  echo "[macOS] Criando venv em '$VENV_DIR'"
  python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
python -m pip install -U pip
pip install -r "$ROOT_DIR/requirements.txt"

echo "[macOS] Dependências instaladas com sucesso."
echo "[macOS] Para executar localmente: scripts/macos/run_local_macos.sh --headed (opcional)"
echo "[macOS] Dica: se necessário, exporte CHROME_PATH para o binário do Chrome:"
echo "        export CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'"