# Para o Advogado que Também Coda

Então você é advogado, usa Linux **e** quer contribuir com código. Bem-vindo ao clube dos masoquistas bem-sucedidos. 🎉

Este guia é para você que quer usar **Claude Code** (a IA da Anthropic no terminal) para evoluir esse projeto — seja corrigindo um bug, adicionando suporte a um novo token ou simplesmente entendendo como tudo foi construído.

---

## O que é o SpecKit?

**SpecKit** é uma metodologia de desenvolvimento guiado por especificação, feita para trabalhar com IAs como o Claude.

A ideia é simples: **você não pede para a IA sair codando.** Você especifica primeiro, como uma petição bem feita — contexto, fundamentos, pedido claro. Só depois a IA implementa.

Funciona assim:

```
Especificar → Clarificar → Planejar → Implementar → Auditar
```

Sabe aquele advogado que entra na audiência sem ter lido o processo? A IA sem spec é exatamente isso — confiante, fluente, e completamente errada.

Com SpecKit, cada feature começa com um documento de especificação que a IA lê antes de escrever uma linha de código. O resultado é código que faz o que foi pedido, não o que a IA "achava que você queria dizer".

---

## Setup — o que você precisa

### 1. Instale o Claude Code

```bash
npm install -g @anthropic/claude-code
```

Abre o terminal, roda esse comando, e você tem o Claude direto no shell. Nada de interface gráfica, nada de copiar e colar — ele lê os arquivos, edita, commita e explica. Funciona como um programador sênior que atende 24/7 e não cobra hora extra.

### 2. Clone o repositório

```bash
git clone https://github.com/vitorcanoas/pje-no-linux.git
cd pje-no-linux
```

### 3. Inicie o Claude Code

```bash
claude
```

Pronto. Agora você tem IA com contexto completo do projeto no terminal.

---

## Fluxo SpecKit — na ordem certa

Execute sempre nesta sequência ao criar uma feature nova. Pular etapas é igual a protocolar sem procuração — tecnicamente vai, mas vai voltar.

| Passo | Comando | O que acontece |
|-------|---------|----------------|
| 1 | `/speckit.specify` | Gera a especificação da feature (histórias de usuário, requisitos, critérios de aceite) |
| 2 | `/speckit.clarify` | A IA detecta ambiguidades e faz até 5 perguntas antes de continuar |
| 3 | `/speckit.plan` | Cria o plano técnico de implementação por fases |
| 4 | `/speckit.implement` | Implementa o código seguindo spec + plano |
| 5 | `/speckit.tasks` | Gera lista de tarefas rastreáveis com status |
| 6 | `/speckit.analyze` | Audita consistência entre spec, plano e código — encontra o que você esqueceu |

### Comandos auxiliares

| Comando | Para que serve |
|---------|---------------|
| `/speckit.constitution` | Exibe os princípios inegociáveis do projeto |
| `/speckit.checklist` | Gera checklist de testes antes do PR |

---

## Os princípios do projeto (a "Constituição")

Este projeto tem regras que não se negocia. Pense como cláusulas pétreas — estão lá por razão técnica séria:

1. **`set -euo pipefail` obrigatório** — qualquer erro aborta o script. Sem surpresas silenciosas. É o equivalente bash de um contrato sem cláusula de imunidade para erro.

2. **SHA256 antes de qualquer instalação** — todo binário baixado é verificado. Se o hash não bater, a instalação aborta. Não é paranoia; é exatamente o que acontece quando o download vem corrompido ou interceptado.

3. **`dpkg -l` após instalar** — verificação real, não otimismo. O script só mostra ✓ se o pacote realmente instalou. Checkmark incondicional é desonestidade técnica.

4. **`mktemp -d` + `trap cleanup EXIT`** — diretório temporário criado na hora certa, destruído na saída. Sem lixo no sistema do usuário.

5. **Versões centralizadas no topo** — uma variável, um lugar para mudar. Zero strings hardcoded espalhadas pelo código.

6. **Consentimento antes de qualquer ação** — o script mostra o que vai fazer e pede confirmação. Só depois baixa coisa.

7. **Mensagens de erro claras** — o público não é técnico. Um erro silencioso pode significar prazo processual perdido. Mensagens vagas são bugs funcionais.

---

## Como adicionar suporte a um novo componente

Exemplo: você quer adicionar suporte a um novo token ou sistema judicial.

```bash
# 1. Crie a branch
git checkout -b 002-suporte-token-xyz

# 2. Inicie o Claude Code e descreva a feature
claude
/speckit.specify Adicionar suporte ao token XYZ — fabricante ABC, driver libxyz.so

# 3. Siga o fluxo
/speckit.clarify
/speckit.plan
/speckit.implement
/speckit.tasks
/speckit.analyze
```

A cada nova feature adicionada ao `instalar.sh`, são obrigatórios:
- Hash SHA256 do binário em `checksums.sha256`
- Verificação pós-instalação com `dpkg -l`
- Entrada correspondente no `desinstalar.sh`

Sem isso, o `shellcheck` vai reclamar e o projeto vai rejeitar o PR. Não porque somos chatos, mas porque advogado sem driver funcionando na véspera do prazo não tem misericórdia.

---

## Verificar qualidade antes do commit

```bash
shellcheck --severity=warning instalar.sh
shellcheck --severity=warning desinstalar.sh
bash -n instalar.sh
```

Zero warnings. Sempre. É o equivalente de revisar a petição antes de protocolar — básico, mas surpreendentemente raro.

---

## Contexto do projeto

**pje-no-linux** nasceu da frustração de um advogado que migrou para o Linux e passou horas tentando fazer o PJe funcionar.

O público-alvo **não é técnico**. Erros silenciosos têm consequências reais — prazo processual perdido, audiência perdida, cliente furioso. Por isso o projeto é obsessivo com verificação, mensagens claras e reversibilidade.

Se você chegou até aqui, provavelmente entende os dois mundos: o do processo judicial e o do processo de software. São mais parecidos do que parecem — nos dois, você define antes de agir, registra tudo, e o erro custa caro.

Bem-vindo ao projeto. Contribuições são bem-vindas. ⚖️💻

---

*Feito com Claude Code + muita cafeína + o prazo sempre chegando.*
