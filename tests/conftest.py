import os
import platform
import sys
from pathlib import Path

# Garantir que o diretório raiz do projeto esteja no PYTHONPATH no momento do import
project_root = Path(__file__).resolve().parents[1]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
# ClientConfig foi introduzido em versões mais novas do Selenium; manter compatibilidade.
try:
    from selenium.webdriver.common.client_config import ClientConfig  # type: ignore
    _HAS_CLIENT_CONFIG = True
except Exception:
    ClientConfig = None  # type: ignore
    _HAS_CLIENT_CONFIG = False
from webdriver_manager.chrome import ChromeDriverManager
from datetime import datetime

def _sanitize_nodeid(nodeid: str) -> str:
    return (
        nodeid.replace("::", "_")
        .replace(":", "_")
        .replace("/", "_")
        .replace("\\", "_")
    )


def pytest_addoption(parser):
    parser.addoption(
        "--headed",
        action="store_true",
        default=False,
        help="Executa com navegador visível (sem headless)",
    )
    parser.addoption(
        "--step-delay",
        action="store",
        default=None,
        help="Delay (segundos) entre etapas de ação para percepção humana (ex.: 0.7)",
    )
    # Novo: delay específico para captura de screenshots, em milissegundos
    # Comentário (PT-BR): Esta opção permite controlar um atraso adicional APENAS
    # antes da captura de cada screenshot, sem afetar o ritmo das ações.
    parser.addoption(
        "--shot-delay-ms",
        action="store",
        default=None,
        help="Delay (milissegundos) ANTES da captura de cada screenshot (ex.: 800)",
    )


@pytest.fixture(scope="session")
def driver(request):
    options = Options()
    # Headless estável em Chrome 109+ (pode ser desativado com --headed ou env PYTEST_HEADED=1)
    env_headed = os.getenv("PYTEST_HEADED", "").lower() in ("1", "true", "yes")
    # Comentário (PT-BR): Detecta ambiente de CI e plataforma para ajustes finos
    is_ci = os.getenv("CI", "").lower() in ("1", "true", "yes") or os.getenv("GITHUB_ACTIONS", "").lower() in ("1", "true", "yes")
    system = platform.system().lower()
    is_macos = system == "darwin"
    is_windows = system == "windows"
    try:
        headed = request.config.getoption("--headed") or env_headed
    except Exception:
        headed = env_headed
    if not headed:
        # Comentário (PT-BR): Usar headless new (estável no Chrome 109+) em todos os ambientes.
        options.add_argument("--headless=new")
    else:
        # Garantir janela visível/maximizada em modo apresentação
        try:
            options.add_argument("--start-maximized")
        except Exception:
            pass
    options.add_argument("--window-size=2560,1440")
    options.add_argument("--force-device-scale-factor=1")
    options.add_argument("--high-dpi-support=1")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-infobars")
    # Comentário (PT-BR): Flags adicionais para estabilidade em headless CI
    options.add_argument("--disable-software-rasterizer")
    options.add_argument("--disable-background-timer-throttling")
    options.add_argument("--disable-backgrounding-occluded-windows")
    options.add_argument("--disable-renderer-backgrounding")
    # Comentário (PT-BR): Evitar porta fixa de remote debugging em todos os SOs
    # para reduzir conflitos com alocação do ChromeDriver em CI.
    # Estratégia de carregamento: em CI usar 'normal' para estabilidade; local 'eager'.
    try:
        options.page_load_strategy = "normal" if is_ci else "eager"
    except Exception:
        pass

    chrome_path = os.environ.get("CHROME_PATH")
    if chrome_path:
        options.binary_location = chrome_path
    else:
        # Fallback específico para macOS: tentar localizar binário do Chrome
        # em caminhos padrão caso CHROME_PATH não esteja definido.
        if is_macos:
            mac_candidates = [
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
                "/Applications/Chromium.app/Contents/MacOS/Chromium",
            ]
            for p in mac_candidates:
                try:
                    if os.path.exists(p):
                        options.binary_location = p
                        break
                except Exception:
                    pass

    service = Service(ChromeDriverManager().install())
    # Timeout HTTP do executor via ClientConfig (evita deprecation warnings)
    # Afinamento por plataforma: no macOS runner do GitHub, comandos podem
    # demorar mais; aumentar o timeout para reduzir ReadTimeout em operações
    # legítimas (ex.: renderização, rolagem, screenshots).
    exec_timeout = 45
    if is_ci:
        # Base mais generosa para CI em geral
        exec_timeout = 60
        # macOS: aumentar ainda mais para evitar ReadTimeoutError (urllib3)
        if is_macos:
            exec_timeout = 120
    if _HAS_CLIENT_CONFIG and ClientConfig is not None:
        driver = webdriver.Chrome(
            service=service,
            options=options,
            client_config=ClientConfig(timeout=exec_timeout),
        )
    else:
        driver = webdriver.Chrome(service=service, options=options)
        try:
            # Compatibilidade com Selenium antigo:
            driver.command_executor.set_timeout(exec_timeout)
        except Exception:
            pass
    driver.implicitly_wait(0)

    if headed:
        try:
            driver.maximize_window()
        except Exception:
            pass

    # Garantir resolução mínima de 1920x1080 mesmo em headless
    try:
        driver.set_window_size(2560, 1440)
    except Exception:
        pass

    # Configuração de delay entre etapas (segundos)
    # Prioridade: --step-delay > STEP_DELAY_MS env > STEP_DELAY_S env > padrão 0
    step_delay_opt = None
    try:
        step_delay_opt = request.config.getoption("--step-delay")
    except Exception:
        step_delay_opt = None
    env_ms = os.getenv("STEP_DELAY_MS")
    env_s = os.getenv("STEP_DELAY_S")
    delay_seconds = 0.0
    try:
        if step_delay_opt is not None:
            delay_seconds = float(step_delay_opt)
        elif env_ms:
            delay_seconds = float(env_ms) / 1000.0
        elif env_s:
            delay_seconds = float(env_s)
    except Exception:
        delay_seconds = 0.0

    # Armazena no driver para que Page Objects possam utilizar
    setattr(driver, "_step_delay_seconds", delay_seconds)

    # Configuração de delay específico para screenshots (milissegundos)
    # Comentário (PT-BR): Prioridade: --shot-delay-ms > SCREENSHOT_DELAY_MS/env > SHOT_DELAY_MS/env > delay_time/env.
    # O valor é convertido para segundos e disponibilizado no driver.
    shot_delay_opt = None
    try:
        shot_delay_opt = request.config.getoption("--shot-delay-ms")
    except Exception:
        shot_delay_opt = None
    env_shot_ms = os.getenv("SCREENSHOT_DELAY_MS") or os.getenv("SHOT_DELAY_MS") or os.getenv("delay_time")
    shot_delay_seconds = 0.0
    try:
        if shot_delay_opt is not None:
            shot_delay_seconds = float(shot_delay_opt) / 1000.0
        elif env_shot_ms:
            shot_delay_seconds = float(env_shot_ms) / 1000.0
    except Exception:
        shot_delay_seconds = 0.0
    try:
        setattr(driver, "_shot_delay_seconds", shot_delay_seconds)
    except Exception:
        pass

    yield driver

    driver.quit()


@pytest.fixture(scope="session")
def screenshots_dir() -> Path:
    d = Path(project_root, "screenshots")
    d.mkdir(parents=True, exist_ok=True)
    return d


@pytest.fixture(autouse=True)
def _auto_screenshot_fixture(request, driver, screenshots_dir):
    # Disponibiliza driver e pasta para hooks
    request.node._driver = driver
    request.node._screenshots_dir = screenshots_dir
    # Também expõe no driver para uso por Page Objects
    try:
        setattr(driver, "_screenshots_dir", screenshots_dir)
    except Exception:
        pass
    # Armazena nodeid no driver para correlação com screenshots de etapas
    try:
        setattr(driver, "_current_nodeid", request.node.nodeid)
    except Exception:
        pass
    yield
    try:
        # Em teardown, captura de screenshot final sem alterar timeout do executor
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        fname = f"{_sanitize_nodeid(request.node.nodeid)}_end_{ts}.png"
        driver.save_screenshot(str(screenshots_dir / fname))
    except Exception:
        pass


def pytest_runtest_makereport(item, call):
    try:
        report = pytest.TestReport.from_item_and_call(item, call)
    except Exception:
        return
    # Captura em falha
    if call.when == "call" and report.failed:
        driver = getattr(item, "_driver", None)
        screenshots_dir = getattr(item, "_screenshots_dir", None)
        if driver and screenshots_dir:
            try:
                ts = datetime.now().strftime("%Y%m%d-%H%M%S")
                fname = f"{_sanitize_nodeid(item.nodeid)}_fail_{ts}.png"
                driver.save_screenshot(str(screenshots_dir / fname))
            except Exception:
                pass