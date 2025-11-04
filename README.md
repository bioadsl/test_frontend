# Teste Automatizado E2E – DemoQA Practice Form

[![E2E Tests](https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml)

Links diretos (mantidos em texto para preservar opção de "Unlink"):
- Repositório Git: https://github.com/bioadsl/test_frontend.git
- Badge SVG: https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml/badge.svg?branch=main
- Página do Workflow CI/CD: https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml

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

Alternativamente, use os scripts auxiliares:

Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1
```

Unix/macOS:
```bash
chmod +x ./scripts/run_tests.sh
./scripts/run_tests.sh
```

### Rodar por marker e gerar relatório JUnit XML

- Apenas testes marcados `e2e`:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e`
  - Unix/macOS: `./scripts/run_tests.sh --marker e2e`

- Gerar relatório JUnit para CI (criado em `reports/junit.xml`):
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -JUnitXml reports\junit.xml`
  - Unix/macOS: `./scripts/run_tests.sh --junitxml reports/junit.xml`

- Combinar marker + JUnit XML:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e -JUnitXml reports\junit.xml`
  - Unix/macOS: `./scripts/run_tests.sh --marker e2e --junitxml reports/junit.xml`

- Passar argumentos extras para o pytest:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -ExtraPytestArgs "-k practice -x"`
  - Unix/macOS: `./scripts/run_tests.sh --extra-args "-k practice -x"`

Observações:
- O teste usa Chrome em modo headless por padrão. Para apresentações ao vivo, rode em modo "headed" (navegador visível):
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e -Headed`
  - Unix/macOS: `./scripts/run_tests.sh --marker e2e --headed`
  - Diretamente via pytest: `.\.venv\Scripts\python -m pytest -m e2e --headed -q`
- O teste gera uma imagem .jpg temporária para upload sem depender de arquivos externos.

## Integração Contínua
- O workflow em `.github/workflows/ci.yml` executa os testes em uma matriz de SO/Python.
- Matriz atual: `ubuntu-latest`, `windows-latest`, `macos-latest` × Python `3.10` e `3.11`.
- Badge de status: atualizado no topo deste README. Caso o repositório seja privado ou ainda não exista, o badge pode retornar `Not Found`; publique o repositório em `bioadsl/test_frontend` para ativar o status.

### Relatórios e cobertura
- JUnit XML: gerado em cada execução (`reports/junit.xml`) e publicado como artifact por job da matriz.
- Resumo no Actions: publicado via `dorny/test-reporter@v1` por job e de forma agregada (job `aggregate`).
- Cobertura: gerada com `pytest-cov` em `reports/coverage.xml` e publicada como artifact.

### Garantir acessibilidade dos links
- Certifique-se de que o repositório `https://github.com/bioadsl/test_frontend.git` existe e está acessível (preferencialmente público) para que os links funcionem.
- Verifique a página do workflow: `https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml` (corrigido sem barra dupla nem parêntese de fechamento indevido).
- O badge em `https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml/badge.svg` ficará visível após o primeiro job do Actions executar.

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
git remote add origin https://github.com/bioadsl/test_frontend.git
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

## Detalhes Técnicos Importantes

- Datepicker: seleção robusta por dropdowns de month e year e dia dentro do mês corrente.
- React-Select: abre o container state / city e seleciona as opções por texto visível, evitando classes dinâmicas.
- Autocomplete: envia texto no subjectsInput e confirma com Enter .
- Upload: evita dependência externa gerando imagem .jpg via base64 (1x1 pixel, válida).
- Overlays: remove possíveis banners fixos ( fixedban / footer ) e usa JS click como fallback no Submit .
Arquivos Criados

- README.md : instruções, cobertura e versionamento.
- requirements.txt : selenium>=4.12.0 , pytest>=7.4.0 , webdriver-manager>=4.0.0 .
- .gitignore : venv e caches.
- tests/conftest.py : configuração do Chrome headless.
- pages/practice_form_page.py : Page Object.
- utils/file_utils.py : criação de .jpg temporária.
- tests/test_practice_form_e2e.py : teste E2E completo.