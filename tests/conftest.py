import os
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager


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
    # Headless estável em Chrome 109+ (pode ser desativado com --headed)
    headed = request.config.getoption("--headed")
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