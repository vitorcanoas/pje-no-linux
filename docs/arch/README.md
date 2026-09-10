# PJe no Arch Linux / Omarchy

> Guia completo do caminho **Arch**. Se você usa Ubuntu, Zorin OS, Linux Mint
> ou Debian, o seu guia é [docs/ubuntu/README.md](../ubuntu/README.md).
> Voltar para a porta de entrada: [README.md](../../README.md)

Cobre **Arch Linux, Omarchy, EndeavourOS, Manjaro e CachyOS**. O instalador é
`instalar-arch.sh`, e ele usa o **AUR** (Arch User Repository) em vez de baixar
`.deb`/zip manualmente.

---

## Requisitos

- Arquitetura `x86_64`
- Grupo **`base-devel`** (compilador e ferramentas de build, necessário para
  compilar pacotes do AUR)
- Um **helper AUR**: `yay` ou `paru`
- `curl`, `unzip`, `git`
- Bash 5.0+, `sudo` disponível, conexão com a internet

Se você ainda não tem `yay` instalado:

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
```

Não sabe se está na família certa? Rode `cat /etc/os-release` — se o campo `ID`
ou `ID_LIKE` mencionar `arch`, é aqui. Se você rodar o script errado, ele avisa
e diz qual é o certo; não quebra nada.

---

## Instalação

```bash
git clone https://github.com/vitorcanoas/pje-no-linux.git
cd pje-no-linux
less instalar-arch.sh      # opcional, e recomendado: leia antes de rodar
bash instalar-arch.sh
```

O script detecta o helper AUR (`yay` ou `paru`), mostra um resumo do que vai
instalar e **pede confirmação antes de compilar qualquer coisa**. Durante a
instalação, o helper AUR exibe o **PKGBUILD** de cada pacote proprietário antes
de compilar — vale a pena ler. Leva de 5 a 15 minutos.

Para ver o que o script faz sem instalar nada:

```bash
bash instalar-arch.sh --help
```

### Opções

| Opção | O que faz |
|---|---|
| `-h`, `--help` | Mostra a ajuda e sai, sem instalar nada e sem criar log. |
| `-y`, `--yes` | Pula **apenas** a confirmação inicial do próprio script. O resumo continua sendo impresso e gravado no log, e a revisão dos PKGBUILDs do AUR continua sendo pedida pelo `yay`/`paru`. Ainda exige um terminal. |

O `--yes` existe para quem administra várias máquinas de um escritório. Ele
**não** dispensa a leitura do PKGBUILD: essa etapa é do helper AUR, e é onde
você vê o código de terceiro que vai compilar e rodar na sua máquina.

### O log

Cada execução grava `~/pje-install-arch-AAAAMMDD-HHMMSS.log`, com permissão
`600` (só você lê). O log começa registrando **qual versão do instalador
rodou** — útil meses depois, quando for preciso saber o que produziu aquela
máquina. Ver [CHANGELOG.md](../../CHANGELOG.md).

---

## O que o Arch/Omarchy já fornece

Do repositório oficial, via `pacman` — pacotes de infraestrutura que outros
programas da sua máquina também podem estar usando:

| Pacote | Para que serve |
|---|---|
| `pcsclite` | Daemon que conversa com o leitor de smartcard |
| `ccid` | Driver dos leitores USB padrão CCID |
| `opensc` | Camada PKCS#11 genérica |
| `p11-kit` | Registro/roteamento dos módulos PKCS#11 |

O desinstalador pergunta separadamente antes de mexer nestes, justamente
porque não foram instalados só para o PJe.

---

## O que este projeto adiciona

Do **AUR**, empacotado pela comunidade (não pelo Arch):

| Pacote AUR | O que é |
|---|---|
| `google-chrome` | Navegador oficial do PJe |
| `sac-core` **ou** `sac-core-legacy` | [PROPRIETÁRIO] Middleware SafeNet/Thales do token |
| `sac-gui` | [PROPRIETÁRIO] Interface gráfica do SafeNet |
| `pje-office` | PJeOffice Pro (assinador oficial do CNJ) |
| `softplan-websigner` | [PROPRIETÁRIO] Web Signer (e-SAJ, TJSP e outros) |
| `shodo` | Opcional — Justiça do Trabalho |

Mais: Microsoft 365 PWA (Word, Excel, PowerPoint, Outlook), o Native Messaging
Host do Web Signer, e a regra polkit do leitor de cartão (abaixo).

### `sac-core` ou `sac-core-legacy`? O script decide

Não é escolha sua, e não é fixo. `sac-core` cobre a linha 5110/5300/IDPrime;
`sac-core-legacy` cobre a linha antiga (5100/JC/PRO, ex-Aladdin). **Instalar o
errado deixa o token ilegível** — o `sac-core` chega a remover
`libeTPkcs11.so` e `/etc/eToken.conf`.

A função `escolher_pacote_sac()` decide pelo dispositivo detectado, usando
`lib/detectar-certificado.sh`. Se quiser só o diagnóstico, sem instalar nada:

```bash
bash lib/detectar-certificado.sh
```

### A regra polkit permanente

O instalador cria `/etc/polkit-1/rules.d/50-pcscd-pje.rules`. Ela libera a
leitura do token (pcsc-lite) para o seu grupo mesmo em sessão não-ativa — sem
ela o token "some" sem erro visível. É uma alteração **permanente** de sistema,
o resumo do instalador avisa antes, e `desinstalar-arch.sh` remove.

---

## Validação após a instalação

Rode estes comandos no Terminal. Você mesmo confere que deu certo, sem precisar
abrir um processo real e sem digitar o PIN em lugar nenhum.

**1. Os programas estão instalados?**

```bash
command -v google-chrome-stable || command -v google-chrome
command -v pjeoffice-pro
command -v pkcs11-tool
```

Cada linha deve imprimir um caminho. Linha vazia = aquele componente não entrou.

**2. Os pacotes do AUR estão registrados?**

```bash
pacman -Q google-chrome pje-office softplan-websigner sac-gui 2>&1
pacman -Q sac-core 2>/dev/null || pacman -Q sac-core-legacy
```

**3. O serviço do leitor está de pé?**

```bash
systemctl is-active pcscd.socket
```

Esperado: `active`. Se vier `inactive`, rode
`sudo systemctl enable --now pcscd.socket`.

**4. O sistema enxerga o seu token?**

Com o token plugado:

```bash
pcsc_scan -c 2>/dev/null | head -20
pkcs11-tool --list-slots
```

O token deve aparecer como um slot com token presente. **Este comando não pede
PIN** e não desbloqueia a chave privada.

**5. O certificado está legível?**

```bash
pkcs11-tool --list-objects --type cert
```

Deve listar o seu certificado (nome, label). Isso lê **apenas objetos
públicos** do token — de novo, sem PIN.

**6. O Native Messaging Host do Web Signer está no lugar?**

```bash
ls -l ~/.config/google-chrome/NativeMessagingHosts/ 2>/dev/null
```

**7. A regra polkit foi criada?**

```bash
ls -l /etc/polkit-1/rules.d/50-pcscd-pje.rules
```

Roteiro mais detalhado, com o que fazer quando algo falha:
[TESTE-RAPIDO.md](../../TESTE-RAPIDO.md).

---

## Passo manual: a extensão Web Signer no Chrome

Esta é a única etapa que o script não consegue fazer por você — o Chrome exige
que a instalação de extensão parta do usuário.

1. Abra o Chrome e acesse:
   <https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol>
2. Clique em **Usar no Chrome** e confirme.

> **Atenção — errata.** Versões anteriores deste repositório indicavam o ID
> `dcngeagmmhegagicpcmpinaoklddcgon`. Esse ID **não é o Web Signer**: é a
> extensão *Web PKI*, da Lacuna Software — outro fabricante, outro produto.
> Quem instalou aquela ficou com o e-SAJ sem assinar.
>
> A prova do ID correto vem do próprio pacote oficial da Softplan: o
> `manifest.json` do Native Messaging Host declara
> `"allowed_origins": ["chrome-extension://bbafmabaelnnkondpfpjmdklbmfnbmol/"]`
> — esse é o único ID que o componente nativo aceita.

---

## Tabela de equivalência Debian ↔ Arch

| Componente | Ubuntu/Debian | Arch (AUR) |
|---|---|---|
| PJeOffice Pro | zip portátil v2.5.16u → `/opt` | `pje-office 2.5.16u-8` |
| Web Signer | `.deb` 2.12.1 | `softplan-websigner 2.15.0.1-2` |
| SafeNet SAC | zip 10.8.1050 (via GlobalSign) | `sac-core` + `sac-gui 10.9.6885-1` |
| Google Chrome | repo apt + chave GPG | `google-chrome` (AUR) |
| Base PKCS#11 | libs via apt | `pcsclite`, `ccid`, `opensc`, `p11-kit` (repositório oficial) |
| Shodo (Justiça do Trabalho) | não coberto | `shodo` (AUR, opcional) |

Dados medidos em 09/09/2026 via API do AUR.

No Arch **não existe** download manual com conferência de SHA256 fixo como no
`instalar.sh`. O AUR já empacota cada componente, e a conferência de
integridade passa a ser a **revisão do PKGBUILD** que o helper (`yay`/`paru`)
mostra antes de compilar. Essa diferença é material: nos dois caminhos você é
protegido, mas por mecanismos distintos, e vale saber em qual você está.

---

## Segurança do certificado — o PIN nunca circula

O `instalar-arch.sh` **nunca pede nem grava o PIN** do seu certificado A3 — nem
em script, nem em arquivo de configuração, nem em variável de ambiente, nem no
log.

O motivo é concreto: no padrão PKCS#11 (o protocolo que o token usa),
*autenticar* e *assinar* rodam na **mesma sessão**, destravada pelo **mesmo
PIN** — a diferença entre as duas operações é só uma flag de uso da chave. Ou
seja: quem tem o seu PIN e o token plugado consegue assinar uma petição em seu
nome, com fé pública. Por isso o PIN não pode circular fora da hora do uso.

A validação de token que o script faz (`pkcs11-tool --list-slots` e
`pkcs11-tool --list-objects --type cert`) lê **apenas objetos públicos** do
token. O PIN só deve ser digitado pelo titular, na hora, na janela do próprio
assinador (PJeOffice, Web Signer etc).

---

## Ambiente gráfico: GNOME vs. Hyprland

O Omarchy usa **Hyprland/Wayland**, não GNOME. O instalador detecta isso e
ajusta o que depende do ambiente gráfico (atalhos, área de transferência).
Onde houver diferença de comportamento, ela vem anotada no log da instalação.

---

## Desinstalar

```bash
bash desinstalar-arch.sh
```

Remove os pacotes do AUR, configurações, atalhos, Native Messaging Hosts e a
regra polkit `/etc/polkit-1/rules.d/50-pcscd-pje.rules`.

Pergunta **separadamente** antes de remover pacotes de infraestrutura genérica
(`pcsclite`, `ccid`, `opensc`, `p11-kit`) e dados pessoais em
`~/.pjeoffice-pro/`, já que outros programas na máquina podem depender deles.

Opções: `--help` mostra o que será removido sem remover nada; `--yes` pula a
confirmação inicial.

---

## Algo deu errado?

- Rode o roteiro de [Validação](#validação-após-a-instalação) acima e veja qual
  passo falha — isso já nomeia o problema.
- [TESTE-RAPIDO.md](../../TESTE-RAPIDO.md) tem o roteiro detalhado.
- [DICAS.md](../../DICAS.md) cobre o dia a dia de quem migrou do Windows.
- O log da instalação está em `~/pje-install-arch-*.log`. Ele **não** contém o
  seu PIN. Contém o ATR do chip (identificador do token), por isso nasce com
  permissão `600` — confira antes de anexar num relato de problema.
- Abra uma issue: <https://github.com/vitorcanoas/pje-no-linux/issues>

---

*Projeto open source licenciado sob [GPL-3.0](../../LICENSE).*
