from typing import Dict
import time
from pathlib import Path
import os
import platform
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import ElementClickInterceptedException
from selenium.webdriver.common.keys import Keys


class PracticeFormPage:
    URL = "https://demoqa.com/automation-practice-form"

    def __init__(self, driver, timeout: int = 20):
        self.driver = driver
        # Ajusta timeout padrão para ambientes mais lentos (macOS/CI)
        try:
            is_ci = (os.getenv("CI", "").lower() in ("1", "true", "yes")) or (
                os.getenv("GITHUB_ACTIONS", "").lower() in ("1", "true", "yes")
            )
        except Exception:
            is_ci = False
        try:
            is_macos = platform.system().lower() == "darwin"
        except Exception:
            is_macos = False
        effective_timeout = timeout
        if is_macos or is_ci:
            effective_timeout = max(timeout, 40)
        self.wait = WebDriverWait(driver, effective_timeout)
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
        # Comentário (PT-BR): Após navegação, remover overlays recorrentes
        # e aguardar carregamento do documento.
        self.driver.execute_script("var b=document.getElementById('fixedban'); if(b){b.remove();}")
        self.driver.execute_script("var a=document.getElementById('adplus-anchor'); if(a){a.remove();}")
        self.driver.execute_script("var f=document.querySelector('footer'); if(f){f.remove();}")
        self._wait_page_loaded(timeout_s=10.0)
        # Comentário (PT-BR): Verifica elemento chave da página; se não presente,
        # faz uma tentativa de atualização para recuperar possíveis travamentos.
        try:
            WebDriverWait(self.driver, 20).until(
                EC.presence_of_element_located((By.ID, "dateOfBirthInput"))
            )
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                WebDriverWait(self.driver, 20).until(
                    EC.presence_of_element_located((By.ID, "dateOfBirthInput"))
                )
            except Exception:
                # Comentário (PT-BR): Não interromper aqui; seguiremos e o wait
                # específico falhará com contexto adequado.
                pass
        # Novo: garantir também a presença do campo de telefone, que é usado cedo
        try:
            WebDriverWait(self.driver, 20).until(
                EC.presence_of_element_located((By.ID, "userNumber"))
            )
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                WebDriverWait(self.driver, 20).until(
                    EC.presence_of_element_located((By.ID, "userNumber"))
                )
            except Exception:
                pass
        self._pause_and_capture("open")

    def _annotate_and_capture(self, element, field_label: str, value: str, state: str = "ativo/focado"):
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", element)
        except Exception:
            pass
        try:
            overlay_id = self.driver.execute_script(
                """
                var el = arguments[0]; var label=arguments[1]; var val=arguments[2]; var st=arguments[3];
                var r = el.getBoundingClientRect();
                var x = r.left + window.scrollX; var y = r.top + window.scrollY;
                var ov = document.createElement('div');
                var id = 'shot-'+Date.now();
                ov.setAttribute('data-shot-overlay', id);
                ov.style.position='absolute';
                ov.style.left=(x)+'px';
                ov.style.top=(y - 28)+'px';
                ov.style.background='rgba(14,17,22,.85)';
                ov.style.color='#fff';
                ov.style.padding='6px 10px';
                ov.style.borderRadius='8px';
                ov.style.font='12px Segoe UI, Arial, sans-serif';
                ov.style.zIndex='2147483647';
                ov.style.border='1px solid #58a6ff';
                ov.textContent = 'Campo: '+label+' • Valor: '+val+' • Estado: '+st;
                document.body.appendChild(ov);
                try { el.focus(); } catch(e){}
                var prev_outline = el.style.outline; var prev_boxshadow = el.style.boxShadow;
                el.setAttribute('data-shot-prev-outline', prev_outline||'');
                el.setAttribute('data-shot-prev-boxshadow', prev_boxshadow||'');
                el.style.outline='2px solid #58a6ff';
                el.style.boxShadow='0 0 0 3px #58a6ff inset, 0 0 8px rgba(88,166,255,.7)';
                return id;
                """,
                element,
                field_label,
                str(value),
                state,
            )
        except Exception:
            overlay_id = None
        # Captura com anotação aplicada
        self._pause_and_capture(f"{self._sanitize(field_label)}")
        # Limpa overlay e restaura estilos
        try:
            self.driver.execute_script(
                """
                var el = arguments[0]; var id = arguments[1];
                if(id){ var ov = document.querySelector('[data-shot-overlay="'+id+'"]'); if(ov) ov.remove(); }
                var prev_outline = el.getAttribute('data-shot-prev-outline')||'';
                var prev_boxshadow = el.getAttribute('data-shot-prev-boxshadow')||'';
                el.style.outline = prev_outline; el.style.boxShadow = prev_boxshadow;
                el.removeAttribute('data-shot-prev-outline'); el.removeAttribute('data-shot-prev-boxshadow');
                """,
                element,
                overlay_id,
            )
        except Exception:
            pass

    # --- Fillers ---
    def fill_name(self, first_name: str, last_name: str):
        first_el = self.wait.until(EC.visibility_of_element_located((By.ID, "firstName")))
        first_el.send_keys(first_name)
        self._annotate_and_capture(first_el, "Nome Completo (Primeiro Nome)", first_name)

        # Aguarda sobrenome com resiliência (evita travas de rede/resposta do driver)
        try:
            last_el = self.wait.until(EC.element_to_be_clickable((By.ID, "lastName")))
        except Exception:
            try:
                # Tentativa de recuperação: refresh e re-wait
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                last_el = self.wait.until(EC.element_to_be_clickable((By.ID, "lastName")))
            except Exception:
                # Último recurso: presença simples para não bloquear o fluxo
                last_el = self.wait.until(EC.presence_of_element_located((By.ID, "lastName")))

        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", last_el)
        except Exception:
            pass
        try:
            last_el.click()
        except Exception:
            try:
                self.driver.execute_script("arguments[0].click();", last_el)
            except Exception:
                pass
        last_el.send_keys(last_name)
        self._annotate_and_capture(last_el, "Nome Completo (Sobrenome)", last_name)

    def fill_email(self, email: str):
        # Aguarda presença/clicabilidade com recuperação em caso de travas
        try:
            el = self.wait.until(EC.element_to_be_clickable((By.ID, "userEmail")))
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                el = self.wait.until(EC.element_to_be_clickable((By.ID, "userEmail")))
            except Exception:
                el = self.wait.until(EC.presence_of_element_located((By.ID, "userEmail")))
        # Centraliza no viewport e tenta o clique com fallback JS
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", el)
        except Exception:
            pass
        try:
            el.click()
        except ElementClickInterceptedException:
            try:
                self.driver.execute_script("arguments[0].click();", el)
            except Exception:
                pass
        el.send_keys(email)
        self._annotate_and_capture(el, "E-mail", email)

    def select_gender(self, gender_label: str = "Male"):
        # Fecha overlays (ex.: datepicker) e aguarda label com resiliência
        try:
            self.driver.find_element(By.TAG_NAME, "body").send_keys(Keys.ESCAPE)
        except Exception:
            pass
        try:
            label = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, f"//label[text()='{gender_label}']"))
            )
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                label = self.wait.until(
                    EC.element_to_be_clickable((By.XPATH, f"//label[text()='{gender_label}']"))
                )
            except Exception:
                label = self.wait.until(
                    EC.presence_of_element_located((By.XPATH, f"//label[text()='{gender_label}']"))
                )
        # Centraliza e tenta clicar com fallback JS
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", label)
        except Exception:
            pass
        try:
            label.click()
        except ElementClickInterceptedException:
            try:
                self.driver.execute_script("arguments[0].click();", label)
            except Exception:
                pass
        self._annotate_and_capture(label, "Gênero", gender_label, state="selecionado")

    def fill_mobile(self, number: str):
        # Aguarda elemento estar clicável e centraliza no viewport
        try:
            el = self.wait.until(EC.element_to_be_clickable((By.ID, "userNumber")))
        except Exception:
            # Tentativa de recuperação: refresh + novo wait
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                el = self.wait.until(EC.element_to_be_clickable((By.ID, "userNumber")))
            except Exception:
                # Como último recurso, tenta presença simples para evitar travas
                el = self.wait.until(EC.presence_of_element_located((By.ID, "userNumber")))
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", el)
        except Exception:
            pass
        try:
            el.click()
        except ElementClickInterceptedException:
            try:
                self.driver.execute_script("arguments[0].click();", el)
            except Exception:
                pass
        el.send_keys(number)
        self._annotate_and_capture(el, "Telefone", number)

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
        # Após seleção, anotar no input de Data de Nascimento
        try:
            dob_input = self.driver.find_element(By.ID, "dateOfBirthInput")
            val = f"{day} {month_text},{year}"
            self._annotate_and_capture(dob_input, "Data de Nascimento", val)
        except Exception:
            self._pause_and_capture("set_birth_date")

    def add_subject(self, subject_text: str):
        # Fecha qualquer overlay remanescente (ex.: datepicker) antes de focar
        try:
            self.driver.find_element(By.TAG_NAME, "body").send_keys(Keys.ESCAPE)
        except Exception:
            pass
        # Aguarda elemento clicável com recuperação em caso de travas
        try:
            subj = self.wait.until(EC.element_to_be_clickable((By.ID, "subjectsInput")))
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                subj = self.wait.until(EC.element_to_be_clickable((By.ID, "subjectsInput")))
            except Exception:
                subj = self.wait.until(EC.presence_of_element_located((By.ID, "subjectsInput")))
        # Centraliza e tenta clicar com fallback JS
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", subj)
        except Exception:
            pass
        try:
            subj.click()
        except ElementClickInterceptedException:
            try:
                self.driver.execute_script("arguments[0].click();", subj)
            except Exception:
                pass
        # Digita e confirma com ENTER
        subj.send_keys(subject_text)
        try:
            subj.send_keys(Keys.ENTER)
        except Exception:
            subj.send_keys("\n")
        self._annotate_and_capture(subj, "Matéria", subject_text)

    def check_hobby(self, hobby_label: str = "Sports"):
        label = self.wait.until(
            EC.element_to_be_clickable((By.XPATH, f"//label[text()='{hobby_label}']"))
        )
        label.click()
        self._annotate_and_capture(label, "Hobby", hobby_label, state="selecionado")

    def upload_picture(self, file_path: str):
        el = self.wait.until(EC.presence_of_element_located((By.ID, "uploadPicture")))
        el.send_keys(file_path)
        try:
            from pathlib import Path as _P
            fname = _P(file_path).name
        except Exception:
            fname = file_path
        self._annotate_and_capture(el, "Upload de Arquivo", fname, state="selecionado")

    def fill_address(self, address: str):
        # Aguarda presença/clicabilidade para reduzir falhas em ambientes lentos
        try:
            el = self.wait.until(EC.element_to_be_clickable((By.ID, "currentAddress")))
        except Exception:
            try:
                self.driver.refresh()
                self._wait_page_loaded(timeout_s=10.0)
                el = self.wait.until(EC.element_to_be_clickable((By.ID, "currentAddress")))
            except Exception:
                el = self.wait.until(EC.presence_of_element_located((By.ID, "currentAddress")))
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", el)
        except Exception:
            pass
        try:
            el.click()
        except Exception:
            try:
                self.driver.execute_script("arguments[0].click();", el)
            except Exception:
                pass
        el.send_keys(address)
        self._annotate_and_capture(el, "Endereço", address)

    def select_state(self, state_text: str):
        # Abre o combo React-Select com maior robustez
        state_container = self.wait.until(EC.presence_of_element_located((By.ID, "state")))
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", state_container)
        except Exception:
            pass
        try:
            # Primeiro tenta clicar normalmente
            self.wait.until(EC.element_to_be_clickable((By.ID, "state"))).click()
        except ElementClickInterceptedException:
            # Fallback via JS em caso de overlay/interceptação
            self.driver.execute_script("arguments[0].click();", state_container)

        # React-Select fornece um input interno; digita o texto e confirma com ENTER
        try:
            internal_input = self.wait.until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "#state input"))
            )
            internal_input.send_keys(state_text)
            # Confirma seleção
            internal_input.send_keys("\n")
        except Exception:
            # Fallback: selecionar pelo texto visível do option
            option = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{state_text}']"))
            )
            option.click()
        try:
            el_state = self.driver.find_element(By.ID, "state")
            self._annotate_and_capture(el_state, "Estado", state_text, state="selecionado")
        except Exception:
            self._pause_and_capture(f"select_state_{self._sanitize(state_text)}")

    def select_city(self, city_text: str):
        city_container = self.wait.until(EC.presence_of_element_located((By.ID, "city")))
        try:
            self.driver.execute_script("arguments[0].scrollIntoView({block:'center'});", city_container)
        except Exception:
            pass
        try:
            self.wait.until(EC.element_to_be_clickable((By.ID, "city"))).click()
        except ElementClickInterceptedException:
            self.driver.execute_script("arguments[0].click();", city_container)

        try:
            internal_input = self.wait.until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "#city input"))
            )
            internal_input.send_keys(city_text)
            internal_input.send_keys("\n")
        except Exception:
            option = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, f"//div[contains(@id,'option') and text()='{city_text}']"))
            )
            option.click()
        try:
            el_city = self.driver.find_element(By.ID, "city")
            self._annotate_and_capture(el_city, "Cidade", city_text, state="selecionado")
        except Exception:
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