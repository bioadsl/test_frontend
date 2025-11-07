from typing import Dict
import time
from pathlib import Path
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import ElementClickInterceptedException


class PracticeFormPage:
    URL = "https://demoqa.com/automation-practice-form"

    def __init__(self, driver, timeout: int = 20):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)
        # Delay configurável entre etapas, vindo do driver (definido em conftest)
        self._delay_s = float(getattr(driver, "_step_delay_seconds", 0.0) or 0.0)
        # Novo: delay específico para screenshots, em segundos
        # Comentário (PT-BR): Este delay é aplicado imediatamente antes da captura
        # da imagem para garantir que elementos tenham sido renderizados.
        self._shot_delay_s = float(getattr(driver, "_shot_delay_seconds", 0.0) or 0.0)
        # Diretório de screenshots por teste
        self._shots_dir = getattr(driver, "_screenshots_dir", None)
        # Identificador do teste atual para correlação
        self._nodeid = getattr(driver, "_current_nodeid", "test")
        # Contador de etapas
        self._step_idx = 0

    def _sanitize(self, s: str) -> str:
        return (
            str(s)
            .replace("::", "_")
            .replace(":", "_")
            .replace("/", "_")
            .replace("\\", "_")
            .replace(" ", "_")
        )

    def _wait_page_loaded(self, timeout_s: float = 5.0):
        """
        Comentário (PT-BR): Aguarda o estado de carregamento do documento ser
        'complete', garantindo que a página esteja totalmente carregada antes
        de capturar a screenshot. Em operações dinâmicas, o readyState já
        estará como 'complete', mas mantemos uma espera curta e resiliente.
        """
        try:
            WebDriverWait(self.driver, timeout_s).until(
                lambda d: d.execute_script("return document.readyState") == "complete"
            )
        except Exception:
            # Comentário (PT-BR): Não falhar o teste por eventuais timeouts;
            # a captura seguirá mesmo assim para não interromper o fluxo.
            pass

    def _pause_and_capture(self, label: str):
        # Pausa para percepção humana nas ações (se configurada)
        if self._delay_s and self._delay_s > 0:
            time.sleep(self._delay_s)
        # Aguarda página totalmente carregada antes da captura
        self._wait_page_loaded(timeout_s=5.0)
        # Aplica delay específico de screenshot, se configurado
        if self._shot_delay_s and self._shot_delay_s > 0:
            time.sleep(self._shot_delay_s)
        # Captura screenshot de etapa
        try:
            if self._shots_dir:
                ts = time.strftime("%Y%m%d-%H%M%S")
                name = f"{self._sanitize(self._nodeid)}_step_{self._step_idx:02d}_{self._sanitize(label)}_{ts}.png"
                p = Path(self._shots_dir) / name
                self.driver.save_screenshot(str(p))
                self._step_idx += 1
        except Exception:
            # Evita falhas do teste por causa de captura
            self._step_idx += 1

    def open(self):
        self.driver.get(self.URL)
        # remover banner fixo que às vezes cobre botões
        self.driver.execute_script("var b=document.getElementById('fixedban'); if(b){b.remove();}")
        self.driver.execute_script("var a=document.getElementById('adplus-anchor'); if(a){a.remove();}")
        self.driver.execute_script("var f=document.querySelector('footer'); if(f){f.remove();}")
        self._pause_and_capture("open")

    # --- Fillers ---
    def fill_name(self, first_name: str, last_name: str):
        self.wait.until(EC.visibility_of_element_located((By.ID, "firstName"))).send_keys(first_name)
        self.driver.find_element(By.ID, "lastName").send_keys(last_name)
        self._pause_and_capture("fill_name")

    def fill_email(self, email: str):
        self.driver.find_element(By.ID, "userEmail").send_keys(email)
        self._pause_and_capture("fill_email")

    def select_gender(self, gender_label: str = "Male"):
        # Usa o texto do label para maior robustez
        label = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//label[text()='{gender_label}']"))
        )
        label.click()
        self._pause_and_capture(f"gender_{gender_label}")

    def fill_mobile(self, number: str):
        self.driver.find_element(By.ID, "userNumber").send_keys(number)
        self._pause_and_capture("fill_mobile")

    def set_birth_date(self, day: int, month_text: str, year: int):
        # Abre o datepicker
        dob = self.wait.until(EC.element_to_be_clickable((By.ID, "dateOfBirthInput")))
        # Garantir visibilidade e centralização para reduzir interceptações
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", dob)
        except Exception:
            pass
        try:
            dob.click()
        except ElementClickInterceptedException:
            # fallback JS caso algo esteja sobrepondo o input
            self.driver.execute_script("arguments[0].click();", dob)
        # Seleciona mês e ano
        month_select = self.wait.until(
            EC.element_to_be_clickable((By.CLASS_NAME, "react-datepicker__month-select"))
        )
        year_select = self.wait.until(
            EC.element_to_be_clickable((By.CLASS_NAME, "react-datepicker__year-select"))
        )
        # Define mês e ano
        month_select.click()
        month_select.find_element(By.XPATH, f".//option[text()='{month_text}']").click()
        year_select.click()
        year_select.find_element(By.XPATH, f".//option[text()='{year}']").click()
        # Seleciona dia dentro do mês corrente
        day_el = self.wait.until(
            EC.element_to_be_clickable(
                (
                    By.XPATH,
                    f"//div[contains(@class,'react-datepicker__day') and not(contains(@class,'outside-month')) and text()='{day}']",
                )
            )
        )
        day_el.click()
        self._pause_and_capture("set_birth_date")

    def add_subject(self, subject_text: str):
        subj = self.wait.until(EC.element_to_be_clickable((By.ID, "subjectsInput")))
        subj.send_keys(subject_text)
        # Confirma com Enter para selecionar a opção do autocomplete
        subj.send_keys("\n")
        self._pause_and_capture(f"add_subject_{self._sanitize(subject_text)}")

    def check_hobby(self, hobby_label: str = "Sports"):
        self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//label[text()='{hobby_label}']"))
        ).click()
        self._pause_and_capture(f"hobby_{self._sanitize(hobby_label)}")

    def upload_picture(self, file_path: str):
        self.wait.until(EC.presence_of_element_located((By.ID, "uploadPicture"))).send_keys(file_path)
        self._pause_and_capture("upload_picture")

    def fill_address(self, address: str):
        self.driver.find_element(By.ID, "currentAddress").send_keys(address)
        self._pause_and_capture("fill_address")

    def select_state(self, state_text: str):
        # Abre o combo React-Select
        state_container = self.wait.until(EC.element_to_be_clickable((By.ID, "state")))
        state_container.click()
        # Seleciona pelo texto visível
        option = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{state_text}']"))
        )
        option.click()
        self._pause_and_capture(f"select_state_{self._sanitize(state_text)}")

    def select_city(self, city_text: str):
        city_container = self.wait.until(EC.element_to_be_clickable((By.ID, "city")))
        city_container.click()
        option = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{city_text}']"))
        )
        option.click()
        self._pause_and_capture(f"select_city_{self._sanitize(city_text)}")

    def submit(self):
        submit_btn = self.wait.until(EC.element_to_be_clickable((By.ID, "submit")))
        try:
            submit_btn.click()
        except ElementClickInterceptedException:
            # fallback JS caso algo ainda esteja sobrepondo
            self.driver.execute_script("arguments[0].click();", submit_btn)
        self._pause_and_capture("submit")

    def get_submission_table(self) -> Dict[str, str]:
        # Aguarda modal
        self.wait.until(EC.visibility_of_element_located((By.ID, "example-modal-sizes-title-lg")))
        rows = self.wait.until(
            EC.presence_of_all_elements_located((By.CSS_SELECTOR, "table tbody tr"))
        )
        result = {}
        for r in rows:
            cols = r.find_elements(By.TAG_NAME, "td")
            if len(cols) >= 2:
                key = cols[0].text.strip()
                val = cols[1].text.strip()
                result[key] = val
        self._pause_and_capture("submission_table")
        return result

    def close_modal(self):
        # fecha modal se necessário
        close_btn = self.wait.until(EC.element_to_be_clickable((By.ID, "closeLargeModal")))
        close_btn.click()
        self._pause_and_capture("close_modal")