import os
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
    try:
        headed = request.config.getoption("--headed") or env_headed
    except Exception:
        headed = env_headed
    if not headed:
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1365,900")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-extensions")
    options.add_argument("--disable-infobars")

    chrome_path = os.environ.get("CHROME_PATH")
    if chrome_path:
        options.binary_location = chrome_path

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    driver.implicitly_wait(0)
    # Reduz timeout HTTP padrão do executor (120s -> 45s)
    try:
        driver.command_executor.set_timeout(45)
    except Exception:
        pass

    if headed:
        try:
            driver.maximize_window()
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
    d = Path(project_root, "reports", "screenshots")
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
        # Em teardown, evitar esperas longas caso o browser tenha morrido
        try:
            driver.command_executor.set_timeout(8)
        except Exception:
            pass
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