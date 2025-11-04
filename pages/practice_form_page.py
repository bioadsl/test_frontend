from typing import Dict
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import ElementClickInterceptedException


class PracticeFormPage:
    URL = "https://demoqa.com/automation-practice-form"

    def __init__(self, driver, timeout: int = 20):
        self.driver = driver
        self.wait = WebDriverWait(driver, timeout)

    def open(self):
        self.driver.get(self.URL)
        # remover banner fixo que às vezes cobre botões
        self.driver.execute_script("var b=document.getElementById('fixedban'); if(b){b.remove();}")
        self.driver.execute_script("var f=document.querySelector('footer'); if(f){f.remove();}")

    # --- Fillers ---
    def fill_name(self, first_name: str, last_name: str):
        self.wait.until(EC.visibility_of_element_located((By.ID, "firstName"))).send_keys(first_name)
        self.driver.find_element(By.ID, "lastName").send_keys(last_name)

    def fill_email(self, email: str):
        self.driver.find_element(By.ID, "userEmail").send_keys(email)

    def select_gender(self, gender_label: str = "Male"):
        # Usa o texto do label para maior robustez
        label = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//label[text()='{gender_label}']"))
        )
        label.click()

    def fill_mobile(self, number: str):
        self.driver.find_element(By.ID, "userNumber").send_keys(number)

    def set_birth_date(self, day: int, month_text: str, year: int):
        # Abre o datepicker
        dob = self.wait.until(EC.element_to_be_clickable((By.ID, "dateOfBirthInput")))
        dob.click()
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

    def add_subject(self, subject_text: str):
        subj = self.wait.until(EC.element_to_be_clickable((By.ID, "subjectsInput")))
        subj.send_keys(subject_text)
        # Confirma com Enter para selecionar a opção do autocomplete
        subj.send_keys("\n")

    def check_hobby(self, hobby_label: str = "Sports"):
        self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//label[text()='{hobby_label}']"))
        ).click()

    def upload_picture(self, file_path: str):
        self.wait.until(EC.presence_of_element_located((By.ID, "uploadPicture"))).send_keys(file_path)

    def fill_address(self, address: str):
        self.driver.find_element(By.ID, "currentAddress").send_keys(address)

    def select_state(self, state_text: str):
        # Abre o combo React-Select
        state_container = self.wait.until(EC.element_to_be_clickable((By.ID, "state")))
        state_container.click()
        # Seleciona pelo texto visível
        option = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{state_text}']"))
        )
        option.click()

    def select_city(self, city_text: str):
        city_container = self.wait.until(EC.element_to_be_clickable((By.ID, "city")))
        city_container.click()
        option = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{city_text}']"))
        )
        option.click()

    def submit(self):
        submit_btn = self.wait.until(EC.element_to_be_clickable((By.ID, "submit")))
        try:
            submit_btn.click()
        except ElementClickInterceptedException:
            # fallback JS caso algo ainda esteja sobrepondo
            self.driver.execute_script("arguments[0].click();", submit_btn)

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
        return result

    def close_modal(self):
        # fecha modal se necessário
        close_btn = self.wait.until(EC.element_to_be_clickable((By.ID, "closeLargeModal")))
        close_btn.click()