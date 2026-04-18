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

### Como instalar — 3 passos simples

**Passo 1** — Abra o Terminal com `Ctrl + Alt + T`

**Passo 2** — Cole o comando e pressione Enter:

```bash
bash instalar.sh
```

![Terminal com o comando de instalação](assets/screenshots/01-terminal.png)

> Quando pedir senha, as letras não aparecem na tela — isso é normal, é uma proteção do sistema.

**Passo 3** — Leia o resumo, confirme com `s` e aguarde. Ao final, aparece o relatório de instalação.

---

### Após instalar — configurar o Web Signer

Esta configuração é feita **uma única vez** no Chrome:

1. Abra o Chrome → clique no ícone do **Web Signer** (escudo azul na barra)
2. Vá em **Configurações** → aba **"Cripto Dispositivos"**
3. No campo **"Nome do arquivo SO"**, digite: `libeToken.so`
4. Clique em **+**

![Configuração do Web Signer](assets/screenshots/03-websigner.png)

---

### Quando tudo estiver funcionando

**PJeOffice — token reconhecido:**

![PJeOffice reconhecendo o token](assets/screenshots/02-pjeoffice.png)

**eSAJ — certificado disponível para assinatura:**

![eSAJ com certificado funcionando](assets/screenshots/04-esaj.png)

---

### Dúvidas e dicas

Consulte o arquivo [DICAS.md](DICAS.md) para:

- Como usar o atalho **Super+Shift+S** (captura de tela como no Windows)
- Atalhos de teclado equivalentes ao Windows
- Histórico de área de transferência (equivalente ao Win+V)
- Como imprimir para PDF
- Como recuperar arquivos deletados
- Como usar o token digital no Linux

---

### Problemas?

O instalador grava um log completo em `~/pje-install-DATA-HORA.log`. Envie esse arquivo para o suporte se algo der errado.

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
  screenshots/       # Capturas de tela ilustrativas do README
  dicas/             # Imagens do guia DICAS.md
```

### Segurança

Cada binário baixado é verificado com **SHA256** antes de ser instalado. Se o hash não bater, a instalação aborta. Os hashes ficam no bloco `CONFIG` no topo do `instalar.sh` e devem ser atualizados pelo mantenedor ao mudar versões.

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
