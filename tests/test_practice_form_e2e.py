import pytest
from pages.practice_form_page import PracticeFormPage
from utils.file_utils import create_temp_jpg


@pytest.mark.e2e
def test_practice_form_submission(driver):
    page = PracticeFormPage(driver)
    page.open()

    # Dados de teste
    first_name = "João"
    last_name = "da Silva"
    email = "joao@email.com"
    gender = "Male"
    phone = "9999999999"
    day, month_text, year = 10, "October", 1990
    subject = "Maths"
    hobby = "Sports"
    address = "Rua dos Testes, 123"
    state = "NCR"
    city = "Delhi"
    img_path = create_temp_jpg()

    # Preenchimento
    page.fill_name(first_name, last_name)
    page.fill_email(email)
    page.select_gender(gender)
    page.fill_mobile(phone)
    page.set_birth_date(day, month_text, year)
    page.add_subject(subject)
    page.check_hobby(hobby)
    page.upload_picture(img_path)
    page.fill_address(address)
    page.select_state(state)
    page.select_city(city)
    page.submit()

    # Validação do modal
    table = page.get_submission_table()

    # Validações principais
    assert table.get("Student Name") == f"{first_name} {last_name}"
    assert table.get("Student Email") == email
    assert table.get("Gender") == gender
    assert table.get("Mobile") == phone
    assert table.get("Date of Birth") == f"{day} {month_text},{year}"
    assert subject in table.get("Subjects", "")
    assert hobby in table.get("Hobbies", "")
    assert table.get("Address") == address
    assert table.get("State and City") == f"{state} {city}"

    # Fecha modal
    page.close_modal()