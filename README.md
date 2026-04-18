# PJe no Linux

Instala em um único comando tudo que um advogado precisa para usar o PJe no Linux.

> README em inglês: [README.en.md](README.en.md)

---

## Para o Advogado

### O que é isso?

Se você acabou de migrar do Windows para Linux (Ubuntu, Zorin OS, Linux Mint) e precisa usar o **PJe** (Processo Judicial Eletrônico), este script instala tudo automaticamente:

| O que instala | Para que serve |
|---|---|
| Google Chrome | Navegador oficial do PJe |
| SafeNet SAC | Driver do token digital (A3) |
| SafeSign IC | Assinatura com certificado A3 |
| PJeOffice Pro | Assinatura de documentos no PJe |
| Web Signer | Extensão de assinatura digital no navegador |
| Antigravity IDE | Ambiente de trabalho recomendado |
| Microsoft 365 PWA | Word, Excel, PowerPoint e Outlook no Linux |

Além disso, configura o atalho **Super+Shift+S** (equivalente ao Win+Shift+S do Windows) para captura de tela.

---

### Como instalar

**Passo 1** — Abra o Terminal (`Ctrl+Alt+T`)

**Passo 2** — Digite o comando abaixo e pressione Enter:

```bash
bash instalar.sh
```

**Passo 3** — Leia o resumo, confirme com `s` e aguarde. O script instala tudo sozinho.

Ao final, aparece um relatório mostrando o que foi instalado com sucesso.

---

### Dúvidas e dicas

Consulte o arquivo [DICAS.md](DICAS.md) para:

- Como usar o token digital no Linux
- Atalhos de teclado equivalentes ao Windows
- Histórico de área de transferência (equivalente ao Win+V)
- Como imprimir para PDF
- Como recuperar arquivos deletados

---

### Problemas?

O instalador grava um log completo em `~/pje-install-DATA-HORA.log`. Se algo der errado, envie esse arquivo para o suporte.

---

## Para o Advogado Curioso (que gosta de tecnologia)

### Estrutura do projeto

```
instalar.sh          # Script principal — instala todos os componentes
desinstalar.sh       # Remove tudo que o instalar.sh instalou
checksums.sha256     # Hashes SHA256 dos binários (para auditoria)
DICAS.md             # Guia de uso para advogados migrando do Windows
assets/
  icons/             # Ícones PNG 128×128 para os PWAs do Microsoft 365
specs/001-rewrite-instalar-sh/
  spec.md            # Especificação completa (histórias de usuário, requisitos)
  plan.md            # Plano de implementação por fases
  tasks.md           # Lista de tarefas com status de conclusão
  research.md        # Pesquisa técnica (versões, URLs, decisões)
  data-model.md      # Modelo de dados e fluxo de estados
  quickstart.md      # Cenários de teste em VM
```

### Segurança

Cada binário baixado é verificado com **SHA256** antes de ser instalado. Se o hash não bater, a instalação aborta. Os hashes ficam no bloco `CONFIG` no topo do `instalar.sh` e devem ser atualizados pelo mantenedor ao mudar versões.

Para calcular o hash de um binário:

```bash
sha256sum nome-do-arquivo.deb
```

### Como desinstalar

```bash
bash desinstalar.sh
```

Remove todos os pacotes, arquivos de configuração, atalhos e reverte o atalho de captura de tela.

### Componentes e versões atuais

| Componente | Versão | Distribuição |
|---|---|---|
| SafeNet SAC | 10.8.1050 | Ubuntu 22.04 |
| SafeSign IC | 4.2.1.0 | Ubuntu 22.04 |
| PJeOffice Pro | v2.5.16u | Linux x64 |
| Web Signer | 2.12.1 | Chrome (64-bit .deb) |

### Requisitos do sistema

- Ubuntu 22.04 / 24.04, Zorin OS 17/18, Linux Mint 21–22, ou Debian 12+
- Arquitetura: `amd64` (64-bit)
- Bash 5.0+
- Conexão com a internet
- `sudo` disponível

### Para desenvolvedores

O projeto usa **SpecKit** como metodologia de especificação. Veja [AGENTS.md](AGENTS.md) para entender o fluxo de comandos e como contribuir com novas funcionalidades.

```bash
# Verificar qualidade do código
shellcheck --severity=warning instalar.sh
shellcheck --severity=warning desinstalar.sh
bash -n instalar.sh
```

---

*Projeto open source. Contribuições são bem-vindas.*
