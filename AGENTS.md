# Guia para LLMs — pje-no-linux

Este repositório usa o fluxo **SpecKit** para desenvolvimento guiado por especificação.
Antes de propor ou implementar qualquer mudança, leia este guia.

---

## Estrutura do repositório

```
specs/
  001-rewrite-instalar-sh/
    spec.md          ← especificação da feature (fonte da verdade)
    plan.md          ← plano técnico de implementação
    tasks.md         ← lista de tarefas rastreáveis
.specify/
  memory/
    constitution.md  ← princípios inegociáveis do projeto
  scripts/bash/
    check-prerequisites.sh
    common.sh
.claude/
  commands/          ← comandos slash do SpecKit
```

---

## Comandos SpecKit (fluxo em ordem)

Execute sempre nesta sequência para uma nova feature:

| Ordem | Comando | O que faz |
|-------|---------|-----------|
| 1 | `/speckit.specify` | Gera `spec.md` a partir de uma descrição ou documento de análise |
| 2 | `/speckit.clarify` | Detecta ambiguidades na spec e resolve com até 5 perguntas |
| 3 | `/speckit.plan` | Cria `plan.md` com plano técnico de implementação |
| 4 | `/speckit.implement` | Implementa o código seguindo `spec.md` + `plan.md` |
| 5 | `/speckit.tasks` | Gera `tasks.md` com tarefas rastreáveis a partir do plano |
| 6 | `/speckit.checklist` | Gera checklist de verificação e testes |
| 7 | `/speckit.analyze` | Analisa consistência entre spec, plano e código implementado |

Comandos auxiliares:

| Comando | O que faz |
|---------|-----------|
| `/speckit.constitution` | Exibe ou atualiza os princípios do projeto |
| `/speckit.agent` | Recomenda stack técnica com base no `TECH_STACK.md` |

---

## Pré-requisitos para os comandos

Os comandos SpecKit requerem:

1. **Branch com prefixo numérico**: `001-feature-name`, `002-outra-feature`
   - Em repositórios sem git, defina `SPECIFY_FEATURE=001-nome-da-feature`
2. **Diretório da feature**: `specs/001-feature-name/` deve existir com `spec.md`
3. **`plan.md`** obrigatório para `/speckit.implement`, `/speckit.tasks`, `/speckit.analyze`

Verificar ambiente:
```bash
SPECIFY_FEATURE=001-rewrite-instalar-sh \
  bash .specify/scripts/bash/check-prerequisites.sh --json --paths-only
```

---

## Constituição do projeto (princípios inegociáveis)

Leia `.specify/memory/constitution.md` antes de qualquer implementação. Resumo:

1. **Bash seguro por padrão** — `set -euo pipefail` obrigatório, sem `|| true` em comandos críticos
2. **Verificação de integridade** — SHA256 antes de qualquer `dpkg -i` ou execução de binário externo
3. **Detecção de ambiente** — verificar arquitetura (`amd64`) e SO antes de qualquer download
4. **Verificação pós-instalação real** — `dpkg -l` após instalação; nunca checkmark verde incondicional
5. **Diretórios temporários isolados** — `mktemp -d` + `chmod 700` + `trap cleanup EXIT`
6. **Versões centralizadas** — todas as versões em variáveis no topo; zero strings hardcoded
7. **Consentimento do usuário** — resumo pré-instalação com EULA; autostart opt-in

---

## Quality gates (nunca pule)

- `shellcheck --severity=warning` sem warnings antes de qualquer commit
- Cada novo componente instalado com `sudo` exige:
  - Hash SHA256 em `checksums.sha256`
  - Verificação pós-instalação correspondente
  - Entrada no `desinstalar.sh`

---

## Contexto do projeto

**pje-no-linux** é um script instalador para advogados brasileiros que migraram para Linux.
Instala: Google Chrome, SafeNet SAC (driver token A3), SafeSign, PJeOffice, Web Signer,
Microsoft 365 PWA e IDE Antigravity do Google.

O público-alvo não é técnico. Erros silenciosos têm consequências jurídicas reais
(prazo processual perdido por driver quebrado). Mensagens claras e verificações reais
não são opcionais — são o produto.

---

## Como iniciar uma nova feature

```bash
# 1. Crie a branch
git checkout -b 002-nome-da-feature

# 2. Execute o fluxo SpecKit
/speckit.specify Descrição da feature ou caminho para documento de análise
/speckit.clarify
/speckit.plan
/speckit.implement
/speckit.tasks
/speckit.checklist
/speckit.analyze
```
