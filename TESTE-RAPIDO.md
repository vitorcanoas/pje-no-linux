# Teste Rápido — Certificado A3 antes da audiência

> Voltar para a instalação: [README.md](README.md) · English overview:
> [README.en.md](README.en.md) — *this troubleshooting guide is available in
> Portuguese only; the commands themselves are language-neutral.*

Guia de emergência. Siga NA ORDEM: cada passo testa a camada que costuma
quebrar antes da próxima. Pare no primeiro que falhar e resolva ali — não
adianta testar o e-SAJ se o leitor nem aparece pro sistema.

**Nunca digite o PIN em terminal, script ou campo que não seja a janela
pop-up do próprio assinador (PJeOffice ou Web Signer).** Se algo pedir o PIN
fora dessas duas janelas, pare e desconfie.

---

## 0. Diagnóstico em cascata

Rode cada comando, na ordem. Pare no primeiro que não bater com o esperado.

```bash
systemctl status pcscd --no-pager        # 1) serviço de leitoras ativo?
```
**Esperado:** `active (running)`. Se não: `sudo systemctl start pcscd`.

```bash
pcsc_scan                                # 2) leitor/token detectado?
```
**Esperado:** aparece o nome do leitor e, com o token conectado, "Card
inserted" / ATR do cartão (Ctrl+C para sair). Nada aparece → token
desconectado, USB com problema, ou driver do fabricante ausente.

```bash
# 3) PKCS#11 enxerga o certificado (NÃO pede PIN — só lê dados públicos)
pkcs11-tool --module /usr/lib/libeToken.so --list-slots
pkcs11-tool --module /usr/lib/libeToken.so --list-objects --type cert
```
**Esperado:** slot com token presente e o certificado listado com o nome do
titular. Caminho da lib varia por fabricante — se não achar, rode
`find / -iname 'libeToken*.so' -o -iname 'libaetpkss*.so' 2>/dev/null`.
`[SPEC]` comportamento descrito no README deste repo.

```bash
ss -ltnp 2>/dev/null | grep -i java      # 4) PJeOffice rodando e ouvindo?
```
**Esperado:** processo `java` em `LISTEN`. A **porta exata não foi
confirmada em fonte oficial** `[N/D]` — fontes secundárias divergem (8800,
8181, 57200). Confie no processo aparecendo, não no número. Se nada
aparecer, abra o PJeOffice (ícone de bandeja / `pjeoffice-pro` no menu).

**5) Chrome enxerga o Web Signer?** É visual, sem comando confiável — ver
seção 1.

Se 1–4 passarem e o site ainda falhar, o problema está no navegador ou no
cadastro do certificado no tribunal (seções 1, 2 ou 3).

---

## 1. Extensão Web Signer no Chrome

**⚠️ Errata do repositório — corrigida em 09/09/2026:** o ID
`dcngeagmmhegagicpcmpinaoklddcgon`, que constava neste repositório (e no
caminho Ubuntu já publicado), **não é o Web Signer**. É a extensão
**"Web PKI", da Lacuna Software** — produto diferente, que não conversa com
o assinador da Softplan. Quem instalou aquela extensão e nunca viu o
certificado aparecer no e-SAJ/PJe tinha exatamente esta causa.

A extensão certa, **Web Signer, da Softplan**, é:

```
https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol
```

**Prova primária** `[SPEC]`: o pacote oficial da Softplan (`.deb` do Web
Signer 2.15.0.1, baixado de `websigner.softplan.com.br` com TLS verificado)
traz o manifest do Native Messaging Host declarando

```json
"allowed_origins": ["chrome-extension://bbafmabaelnnkondpfpjmdklbmfnbmol/"]
```

Ou seja: esse é o **único** ID que o componente nativo aceita — qualquer
outra extensão simplesmente não fala com o binário instalado. Confirmação
cruzada `[LIVE]`: na Chrome Web Store o ID errado devolve **301** para o
slug `/detail/web-pki/...` (Lacuna), e o correto devolve **200** com título
"Web Signer".

**Confira em `chrome://extensions`:** o card "Web Signer" deve estar
presente e **ativado** (chave azul). Se em vez disso houver uma extensão
"Web PKI", desinstale e instale a correta — no e-SAJ/PJe ela não substitui.

**Como saber se está "conversando" com o componente nativo** (não só
instalada): abra o e-SAJ, aba "Certificado digital". Se a extensão está
instalada mas o componente nativo não está rodando, a página tende a
**travar carregando** ou **não listar nenhum certificado** `[INFER]`
(relatos de suporte Softplan/OAB — texto exato da mensagem não confirmado
em fonte primária). Sinal de que está tudo certo: ao clicar em
"Certificado digital" abre uma **janela separada do sistema** (não uma aba)
listando os certificados do token — isso só acontece com extensão e
componente nativo funcionando juntos `[INFER]`.

---

## 2. e-SAJ / TJSP

```
https://esaj.tjsp.jus.br/sajcas/login
```
A página tem duas abas: **"CPF/CNPJ"** (senha) e **"Certificado digital"**
— clique na segunda. `[SPEC]` confirmado em 09/09/2026.

**Deu certo quando:** abre uma janela do sistema listando os certificados
do token; você escolhe o seu e **digita o PIN só ali**. Depois o e-SAJ
carrega autenticado.

**Erros comuns** (significado — texto exato não confirmado em fonte
oficial) `[INFER]`:
- **Nenhum certificado listado / janela não abre** → componente nativo do
  Web Signer não está rodando ou não enxerga o token (volte ao item 3 e 1).
- **Login rejeitado após escolher o certificado** → geralmente certificado
  vencido, ou CPF do certificado não bate com o cadastro no e-SAJ.
- **Página trava "carregando"** → reinicie o Chrome (comum após
  instalar/atualizar a extensão) ou o serviço nativo caiu.

---

## 3. PJe / TRT-15 (Campinas)

O login do PJe migrou para a **PDPJ**, SSO baseado em Keycloak/OAuth2, em
`sso.cloud.pje.jus.br`. Não há indicação de que o TRT-15 fuja desse padrão.
`[SPEC]` via docs.pje.jus.br e comunicado do TRT-15 (set/2025).

**Fluxo por certificado:**
1. Acesse o PJe do TRT-15 (redireciona ao SSO da PDPJ) e escolha
   **certificado digital** (ao lado de CPF/senha e Gov.br).
2. Precisa do **PJeOffice Pro rodando** (seção 4) — sem ele o SSO não
   aciona o assinador.
3. **Desde nov/2025 o PJe exige MFA obrigatório** (Portaria CNJ 140/2024):
   mesmo com certificado, pode pedir código de app autenticador (Google
   Authenticator, FreeOTP) cadastrado no primeiro acesso. `[SPEC]`
   comunicado do TRT-15, set/2025. **Se nunca configurou, faça hoje** — o
   cadastro inicial mostra QR code e não é instantâneo.

**Achado relevante:** desde a versão 142, o Chrome passou a bloquear por
padrão que sites conversem com programas locais ("Local Network Access") —
afeta exatamente `sso.cloud.pje.jus.br`/e-SAJ falando com PJeOffice/Web
Signer. `[INFER]` (mecanismo real e documentado pelo Google; efeito
específico no PJe não confirmado em nota oficial do CNJ). Se aparecer aviso
do Chrome pedindo para "buscar e se conectar a qualquer dispositivo na sua
rede local", clique **Permitir**. Sem aviso e sem conectar, teste
`chrome://flags/#local-network-access-check` → **Disabled** → reinicie.

---

## 4. PJeOffice — quando precisa estar rodando

Precisa estar **aberto antes** de logar no PJe ou assinar qualquer coisa —
não abre sozinho quando o site pede. Verifique o ícone na bandeja do
sistema. Confirme com o comando da seção 0, item 4
(`ss -ltnp | grep -i java`) — processo `java` em `LISTEN` é o sinal, a
porta exata não veio confirmada em fonte primária `[N/D]`.

---

## 5. Plano B para amanhã

Ordem do mais rápido ao mais trabalhoso:

1. **Trocar de navegador**: se o Chrome travar na comunicação local
   (seção 3), teste Firefox ou Edge — o bloqueio é específico do Chrome
   142+ `[INFER]`.
2. **Windows em dual-boot**: se o certificado já funciona lá, reinicie e
   entre só para a audiência — mais confiável em cima da hora.
3. **Avisar a secretaria do TRT-15 ou o cartório do TJSP com
   antecedência**: dificuldade técnica pode justificar prazo/reagendamento,
   mas é decisão do juízo, não automática.
4. **Confirme se a audiência é por videoconferência** — nesse caso o
   acesso ao PJe/e-SAJ pode não ser necessário no horário da audiência em
   si, só depois para juntar documentos.
5. **Protocolo físico** só se o prazo e a vara permitirem — último
   recurso.

Nenhuma alternativa envolve gravar ou automatizar o PIN. Ele é sempre
digitado à mão, na hora, na janela do assinador — em qualquer sistema.
