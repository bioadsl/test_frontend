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

### Gerar relatório HTML (pytest-html)
- Instale as dependências (já incluímos `pytest-html` em `requirements.txt`).
- Gerar relatório HTML auto-contido em `reports/pytest.html`:
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e -HtmlReport reports\pytest.html`
  - Unix/macOS: `./scripts/run_tests.sh --marker e2e --html reports/pytest.html`
- Combinar JUnit XML + HTML (útil para CI manter o resumo e ter um relatório navegável):
  - Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e -JUnitXml reports\junit.xml -HtmlReport reports\pytest.html`
  - Unix/macOS: `./scripts/run_tests.sh --marker e2e --junitxml reports/junit.xml --html reports/pytest.html`

### Script completo de relatório e screenshots (Windows)
- Para executar testes, gerar `pytest.html`, capturar screenshots e abrir automaticamente o relatório:
  - `scripts\run_report_windows.bat` (adicione `--headed` para abrir o navegador durante o teste)
- Saídas geradas:
  - `reports\pytest.html`: relatório HTML padrão do pytest-html
  - `reports\junit.xml`: JUnit XML
  - `reports\screenshots\*.png`: screenshots automáticos por caso de teste (fim e falha)
  - `reports\summary.html`: resumo com nome de suite/caso, status, screenshots e link para `pytest.html`

Observações:
- O teste usa Chrome em modo headless por padrão. Para apresentações ao vivo, rode em modo "headed" (navegador visível):
- Windows: `powershell -ExecutionPolicy Bypass -File .\scripts\run_tests.ps1 -Marker e2e -Headed`
- Unix/macOS: `./scripts/run_tests.sh --marker e2e --headed`
- Diretamente via pytest: primeiro habilite `PYTEST_HEADED`, depois execute pytest:
  - Windows CMD: `set PYTEST_HEADED=1 && .\.venv\Scripts\python -m pytest -m e2e -q`
  - PowerShell: `$env:PYTEST_HEADED='1'; .\.venv\Scripts\python -m pytest -m e2e -q`
  - Unix/macOS: `PYTEST_HEADED=1 ./.venv/bin/python -m pytest -m e2e -q`
- O teste gera uma imagem .jpg temporária para upload sem depender de arquivos externos.

### Delay configurável entre etapas (percepção humana)
- Para evitar que “prints”/screenshots sejam idênticos em execuções muito rápidas e permitir análise passo a passo, foi adicionado um delay configurável entre cada ação do Page Object.
- Como usar:
  - Via CLI: passe `--step-delay=<segundos>` para o pytest (ex.: `--step-delay=0.7`).
    - Windows (runner pronto): `scripts\run_report_windows.bat --headed --step-delay=0.7`
    - Direto: `.\.venv\Scripts\python -m pytest -m e2e --step-delay=0.7`
  - Via variável de ambiente: `STEP_DELAY_MS` (milissegundos) ou `STEP_DELAY_S` (segundos).
    - Ex.: PowerShell: `$env:STEP_DELAY_MS='700'; .\.venv\Scripts\python -m pytest -m e2e`
- Recomendação: `700ms` (~`0.7s`) para boa percepção sem prejudicar estabilidade.
- O delay mantém a sequência lógica, não altera a lógica de waits, e captura screenshots após cada ação relevante (open, preenchimentos, seleções, submit, modais), além de final e falha.

## Integração Contínua
- O workflow em `.github/workflows/ci.yml` executa os testes em uma matriz de SO/Python.
- Matriz atual: `ubuntu-latest`, `windows-latest`, `macos-latest` × Python `3.10` e `3.11`.
- Badge de status: atualizado no topo deste README. Caso o repositório seja privado ou ainda não exista, o badge pode retornar `Not Found`; publique o repositório em `bioadsl/test_frontend` para ativar o status.

### Disparo manual e via script (GitHub CLI)
- Requisitos:
  - `winget` instalado (`winget --version`)
  - GitHub CLI (`gh`) instalado. Se não estiver no `PATH`, o script tenta localizar `gh.exe` em `C:\Program Files\GitHub CLI\` ou `%LOCALAPPDATA%\Programs\gh\bin` e ajustar o `PATH` da sessão.
- Autenticação:
  - Sessão atual (PowerShell): ``$env:GH_TOKEN='<SEU_TOKEN>'``
  - Persistente (PowerShell): ``[System.Environment]::SetEnvironmentVariable('GH_TOKEN','<SEU_TOKEN>','User')``
  - Alternativa: `gh auth login` (fluxo via navegador)
- Permissões do token para disparo manual (`workflow_dispatch`):
  - PAT classic: escopos `repo` e `workflow`
  - PAT fine‑grained: repository `bioadsl/test_frontend` com `Actions: Read and write`; `Contents: Read`; `Metadata: Read` (autorize SSO se necessário)
- Como executar o script de disparo:
  - Padrão (aguarda conclusão): `scripts\gh_actions_run.bat --wait`
  - Especificando branch: `scripts\gh_actions_run.bat --ref main --wait`
  - Especificando workflow por nome/ID: `scripts\gh_actions_run.bat --workflow "E2E Tests" --wait` ou `--workflow 203842521`
- O script faz:
  - Checagens de ambiente (`git`, `gh`) e rede
  - Valida autenticação (`gh auth status`)
  - Resolve workflow automaticamente: tenta `ci.yml`; se não existir, escolhe o primeiro workflow ativo via `gh workflow list` (JSON)
  - Dispara o run com `gh workflow run` (requer `workflow_dispatch` no YAML)
  - Monitora até finalizar com `gh run watch --exit-status` (sem necessidade de `jq`)
  - Gera logs em `logs\gh_actions_<timestamp>.log` e `logs\gh_actions_latest.log`
- Alternativa sem alterar token (via `push`):
  - `git commit --allow-empty -m "chore(ci): trigger E2E"`
  - `git push origin main`
  - Acompanhar: `gh run list -R bioadsl/test_frontend --workflow "E2E Tests" --limit 1 --json databaseId,url,status` e `gh run watch <run-id> -R bioadsl/test_frontend --exit-status`

Observações:
- Para disparo manual, o workflow precisa ter `on: workflow_dispatch` (já configurado em `.github/workflows/ci.yml`).
- Em novas sessões de terminal, `gh` normalmente é reconhecido; se não, reabra o terminal.
- No Windows PowerShell, use `;` para encadear comandos; evite `&&`.

### Relatórios e cobertura
- JUnit XML: gerado em cada execução (`reports/junit.xml`) e publicado como artifact por job da matriz.
- HTML (pytest-html): gerado como relatório navegável (`reports/pytest.html`) e publicado como artifact por job.
- Resumo no Actions: publicado via `dorny/test-reporter@v1` por job e de forma agregada (job `aggregate`).
- Cobertura: gerada com `pytest-cov` em `reports/coverage.xml` e publicada como artifact.

### Garantir acessibilidade dos links
- Certifique-se de que o repositório `https://github.com/bioadsl/test_frontend.git` existe e está acessível (preferencialmente público) para que os links funcionem.
- Verifique a página do workflow: `https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml` (corrigido sem barra dupla nem parêntese de fechamento indevido).
- O badge em `https://github.com/bioadsl/test_frontend/actions/workflows/ci.yml/badge.svg` ficará visível após o primeiro job do Actions executar.

## Correções de Links e Verificação
- Padronização de segurança em links externos: adicionado `rel="noopener noreferrer"` aos links que abrem em nova aba.
- Acessibilidade: incluído `aria-label` em links de navegação (Ações, Resultados, Casos) e no link para `pytest.html`.
- Consistência de navegação: verificados e corrigidos os apontamentos internos entre `reports/action.html`, `reports/results.html` e `reports/cases.html`.

### Como validar os links automaticamente
1. Suba o servidor local na raiz do projeto (qualquer servidor estático funciona; exemplo usando Python):

```powershell
python -m http.server 8000
```

2. Execute o verificador:

```powershell
python .\scripts\check_links.py http://localhost:8000/
```

Saída esperada: todos os links com status 200 (ou 3xx válido) e sem erros. O verificador também alerta sobre itens de acessibilidade (`aria-label`) e segurança (`rel` em `_blank`).


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
- scripts/gh_actions_run.bat : runner para GitHub Actions (Windows), com fallback de PATH para `gh.exe`, resolução automática de workflow, disparo com `gh workflow run` e monitoria com `gh run watch`.
- requirements.txt : selenium>=4.12.0 , pytest>=7.4.0 , webdriver-manager>=4.0.0 .
- .gitignore : venv e caches.
- tests/conftest.py : configuração do Chrome headless.
- pages/practice_form_page.py : Page Object.
- utils/file_utils.py : criação de .jpg temporária.
- tests/test_practice_form_e2e.py : teste E2E completo.