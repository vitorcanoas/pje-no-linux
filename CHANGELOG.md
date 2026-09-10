# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

A versão do instalador fica em `PJE_LINUX_VERSION`, no topo de `instalar.sh` e
de `instalar-arch.sh`. Ela é impressa no cabeçalho e **gravada no log da
instalação** — assim é possível saber, meses depois, qual versão do instalador
produziu aquela máquina.

## Convenção deste repositório: mudança de versão/hash conta como mudança

Este repositório instala **software proprietário de terceiros** (SafeNet SAC,
SafeSign IC, Web Signer da Softplan, PJeOffice Pro do CNJ). Quando a versão ou
o SHA256 de qualquer um desses componentes muda, isso vira **entrada no
CHANGELOG**, mesmo que nenhuma linha de lógica tenha mudado.

O motivo é auditoria, não burocracia: um advogado precisa poder provar qual
binário foi instalado na máquina dele e quando. Uma entrada dessas tem a forma:

```
### Alterado
- PJeOffice Pro `v2.5.16u` → `v2.5.17`
  SHA256 `6087391759c7…6882c4c7` → `a1b2c3d4…`
  Fonte: https://pje-office.pje.jus.br/pro/ (baixado em AAAA-MM-DD)
```

Regras:

- **Sempre as duas pontas**: versão antiga → nova, hash antigo → novo.
- **Sempre a fonte e a data do download** — o servidor do fornecedor pode
  republicar o mesmo número de versão com bytes diferentes.
- Componente instalado via AUR (caminho Arch) não tem hash fixo aqui: a
  integridade é conferida pelo PKGBUILD. Nesse caso registre o **nome do pacote
  AUR** e o motivo da troca (ex.: `sac-core` → `sac-core-legacy`).
- No caminho Ubuntu/Debian, quem gera os hashes é `./atualizar-hashes.sh`;
  registre aqui o resultado dele, não o comando.

---

## [Não publicado]

### Adicionado

- **Suporte a Arch Linux e derivados** (Omarchy, EndeavourOS, Manjaro,
  CachyOS): `instalar-arch.sh` e `desinstalar-arch.sh`. Os componentes
  proprietários vêm do AUR, que já os empacota; a revisão do PKGBUILD fica com
  o usuário — o helper AUR mostra o diff antes de compilar.
- **`lib/detectar-certificado.sh`**: detector multi-certificado compartilhado
  por `source` entre os dois instaladores. Traz a matriz de modelos de token e
  o teste de middleware, sem nunca pedir, ler ou gravar o PIN.
- **`escolher_pacote_sac()`** em `instalar-arch.sh`: decide entre `sac-core`
  (5110/5300/IDPrime) e `sac-core-legacy` (5100/JC/PRO, ex-Aladdin) pelo
  dispositivo detectado. Instalar o pacote errado deixa o token ilegível.
- **`TESTE-RAPIDO.md`**: roteiro curto de validação pós-instalação.
- **`.gitignore`**.
- **`CHANGELOG.md`** (este arquivo), com a convenção de registrar mudança de
  versão/hash de componente proprietário.
- **`PJE_LINUX_VERSION`** nos instaladores, impressa no cabeçalho e gravada no
  log — antes o log não dizia qual versão do instalador havia rodado.
- **`lib/detectar-distro.sh`**: detecção de família de distribuição
  (`debian`/`arch`) e guard-rail cruzado. Quem roda o script errado recebe o
  nome da própria distro e o comando certo na tela, em vez de um erro genérico
  de `apt-get`/`pacman` não encontrado.
- **`--help` e `--yes`/`-y`** nos quatro scripts. O `--yes` pula apenas a
  confirmação inicial do próprio script; **nunca** pula a revisão do PKGBUILD
  do AUR.
- **`docs/arch/README.md` e `docs/ubuntu/README.md`**: guia por caminho, com
  seção **Validação** (comandos `command -v` que o usuário roda sozinho para
  conferir que deu certo). O `README.md` raiz virou porta de entrada enxuta.
- **`.github/workflows/shellcheck.yml`**: shellcheck (`-S warning`) em todo
  push e pull request.

### Corrigido

- **Errata — ID da extensão Web Signer no Chrome.** Este repositório indicava
  `dcngeagmmhegagicpcmpinaoklddcgon`. Esse ID **não é o Web Signer**: é a
  extensão *Web PKI*, da Lacuna Software — outro fabricante, outro produto.
  Quem instalou aquela extensão ficou com o e-SAJ sem assinar, porque o Native
  Messaging Host da Softplan recusa a origem.

  O ID correto é **`bbafmabaelnnkondpfpjmdklbmfnbmol`**, confirmado por fonte
  primária: o campo `allowed_origins` do manifest oficial de Native Messaging
  Host distribuído pela própria Softplan contém
  `chrome-extension://bbafmabaelnnkondpfpjmdklbmfnbmol/`.

  **Esta errata afeta os dois caminhos** — Ubuntu/Debian e Arch. Quem seguiu
  qualquer versão anterior do `README.md`, do `README.en.md` ou do
  `instalar.sh` deve remover a extensão errada e instalar a correta:
  <https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol>

- Permissão do log de instalação no caminho Arch: o arquivo passou a nascer
  sob `umask 077`. Antes ele nascia `644` e havia uma janela em que o log — que
  contém o ATR do chip, identificador persistente do token — ficava legível
  para todos os usuários da máquina. O `chmod 600` posterior fechava a porta
  tarde demais.

### Segurança

- Nenhum script deste repositório pede, lê, grava ou registra em log o **PIN**
  do certificado. Isso é invariante do projeto, não uma opção de configuração:
  no PKCS#11, autenticar e assinar rodam na mesma sessão destravada pelo mesmo
  PIN — quem tem o PIN assina em nome do titular.

---

## [1.0.0] — a publicar

Primeira versão numerada. Marca o estado do repositório no momento em que o
suporte a Arch/Omarchy e o detector multi-certificado entraram, e passa a
valer como linha de base para as entradas acima.
