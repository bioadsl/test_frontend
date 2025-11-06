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

    if headed:
        try:
            driver.maximize_window()
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
    yield
    try:
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