# Teste Automatizado E2E – DemoQA Practice Form

Este projeto implementa uma suíte de testes E2E usando Selenium + Python + Pytest para validar o fluxo de cadastro em `https://demoqa.com/automation-practice-form`.

## Objetivo dos Testes
- Preencher e enviar o formulário com sucesso com:
  - Nome: João da Silva
  - Email: joao@email.com
  - Gênero: Male
  - Telefone: 9999999999
  - Data de nascimento: 10 de Outubro de 1990
  - Matéria favorita: Maths
  - Hobby: Sports
  - Upload de arquivo: imagem .jpg
  - Endereço: "Rua dos Testes, 123"
  - Estado: NCR
  - Cidade: Delhi
- Validar a submissão através da tabela no modal de confirmação.
- Tratar componentes customizados (autocomplete, datepicker, react-select, upload).

## Requisitos
- Python 3.9+
- Google Chrome instalado (ou ajuste para Edge/Firefox se preferir)

## Instalação e Execução
1. Crie e use um ambiente virtual e instale dependências:

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -U pip
.\.venv\Scripts\python -m pip install -r requirements.txt
```

2. Execute os testes:

```powershell
.\.venv\Scripts\python -m pytest -q
```

Observações:
- O teste usa Chrome em modo headless por padrão.
- O teste gera uma imagem .jpg temporária para upload sem depender de arquivos externos.

## Estrutura do Projeto
- `tests/test_practice_form_e2e.py`: Teste E2E principal.
- `tests/conftest.py`: Configuração do WebDriver (Chrome headless via webdriver-manager).
- `pages/practice_form_page.py`: Page Object com ações e seletores.
- `utils/file_utils.py`: Utilitário para geração de imagem .jpg temporária.
- `requirements.txt`: Dependências do projeto.

## Boas Práticas Adotadas
- Page Object Model para isolamento de seletores e ações.
- `WebDriverWait` e `ExpectedConditions` para elementos assíncronos.
- Seletores estáveis e tolerantes a mudanças (por texto e atributos semânticos sempre que possível).
- Tratamento de banners dinâmicos que podem bloquear o submit.
- Execução headless para maior estabilidade em CI.

## Versionamento (GitHub/GitLab)
Para disponibilizar o projeto:

```powershell
# Inicializar repositório
git init
git add .
git commit -m "feat(e2e): suite de testes DemoQA practice form"

# Substitua pela URL do seu repositório
git remote add origin https://github.com/<seu-usuario>/<seu-repo>.git
git branch -M main
git push -u origin main
```

Se preferir GitLab:
```powershell
git remote add origin https://gitlab.com/<seu-usuario>/<seu-repo>.git
git push -u origin main
```

## Ajustes
- Caso o Chrome não esteja disponível, adapte o `conftest.py` para Edge/Firefox.
- Em ambientes restritos, remova `--headless=new` e rode com GUI.