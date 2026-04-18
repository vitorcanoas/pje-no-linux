# PJeOffice Pro + Certificado Digital no Linux 🐧⚖️

> Guia completo para advogados que estão migrando para o Linux — ou que simplesmente querem usar o PJeOffice sem dor de cabeça.

Feito por um advogado, para advogados. Depois de horas de tentativa e erro, este repositório reúne tudo que você precisa para funcionar no **Zorin OS**, **Ubuntu** e **Linux Mint**.

---

## Instalação em um único comando

Abra o terminal (`Ctrl + Alt + T`) e cole:

```bash
curl -fsSL https://raw.githubusercontent.com/vitorcanoas/pjeofficelinuxparaadvogados/main/instalar.sh | bash
```

O script instala e configura tudo automaticamente:
- ✅ PJeOffice Pro (versão mais recente do CNJ)
- ✅ Driver SafeNet para tokens **eToken 5100/5110**
- ✅ Driver OpenSC para tokens **GD Starsign** e outros
- ✅ Ícone bonito na área de trabalho
- ✅ PJeOffice abrindo automaticamente no login

---

## Compatibilidade

| Sistema Operacional | Versão | Status |
|---|---|---|
| Zorin OS | 17, 18 | ✅ Testado |
| Ubuntu | 22.04, 24.04 | ✅ Compatível |
| Linux Mint | 21, 22 | ✅ Compatível |

---

## Tokens suportados

| Token | Fabricante | Emissores comuns | Driver |
|---|---|---|---|
| eToken 5100 | SafeNet/Thales | Certisign, Serasa, Valid, Soluti | SafeNet Authentication Client (SAC) |
| eToken 5110 | SafeNet/Thales | Certisign, Serasa, Valid, Soluti | SafeNet Authentication Client (SAC) |
| GD Starsign | G&D | Certisign | OpenSC (já incluído no Linux) |
| Pronova | Athena | Vários emissores | OpenSC (já incluído no Linux) |

> **Não sabe qual token você tem?** Olhe o token físico — o fabricante geralmente está impresso nele. Se for cinza/preto da Certisign com formato de pendrive, é SafeNet eToken.

---

## Instalação manual (passo a passo)

Se preferir fazer manualmente, ou se o script automático falhar:

### 1. Instalar dependências

```bash
sudo apt-get update
sudo apt-get install -y pcscd opensc opensc-pkcs11 libccid libpcsclite1 wget unzip
```

### 2. Instalar o driver SafeNet (para tokens eToken)

```bash
wget https://www.globalsign.com/en/safenet-drivers/USB/10.8/GlobalSign-SAC-Ubuntu-2204.zip -O /tmp/sac.zip
unzip /tmp/sac.zip -d /tmp/sac/
sudo dpkg -i /tmp/sac/Ubuntu-2204/safenetauthenticationclient_10.8.1050_amd64.deb
sudo systemctl restart pcscd
```

Após instalar, teste se seu token é reconhecido:

```bash
pkcs11-tool --module /usr/lib/libeToken.so --list-slots
```

Você deve ver o nome do seu certificado listado (ex: `CERTIFICAÇÃO OAB`).

### 3. Baixar e instalar o PJeOffice Pro

```bash
wget https://pje-office.pje.jus.br/pro/pjeoffice-pro-linux_x64.zip -O /tmp/pje.zip
mkdir -p ~/pjeoffice-pro
unzip /tmp/pje.zip -d ~/pjeoffice-pro
chmod +x ~/pjeoffice-pro/pjeoffice-pro.sh
chmod +x ~/pjeoffice-pro/jre/bin/java
```

### 4. Configurar o driver de certificado no PJeOffice

Crie o arquivo de configuração:

```bash
mkdir -p ~/.pjeoffice-pro
cat > ~/.pjeoffice-pro/pjeoffice-pro.json << 'EOF'
{
   "drivers": [
     {
       "name": "Token SafeNet (eToken 5100/5110 — Certisign, Serasa, Valid)",
       "library": "/usr/lib/libeToken.so"
     },
     {
       "name": "Token GD Starsign / OpenSC (outros tokens)",
       "library": "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
     }
   ],
   "currentDriver": "Token SafeNet (eToken 5100/5110 — Certisign, Serasa, Valid)"
}
EOF
```

### 5. Criar ícone e autostart

```bash
# Ícone no menu e área de trabalho
cat > ~/.local/share/applications/PJeOfficePro.desktop << EOF
[Desktop Entry]
Name=PJeOffice Pro
Exec=$HOME/pjeoffice-pro/pjeoffice-pro.sh
Icon=$HOME/pjeoffice-pro.png
Terminal=false
Type=Application
Categories=Office;Java;
StartupWMClass=br-jus-cnj-pje-office-imp-PjeOfficeApp
EOF

# Abrir automaticamente no login
mkdir -p ~/.config/autostart
cp ~/.local/share/applications/PJeOfficePro.desktop ~/.config/autostart/
```

### 6. Abrir o PJeOffice

```bash
~/pjeoffice-pro/pjeoffice-pro.sh
```

---

## Como usar com o token

1. Conecte seu token USB antes de abrir o PJeOffice
2. Abra o PJeOffice Pro (ícone na área de trabalho)
3. Acesse o sistema do tribunal pelo navegador (ex: TRT, TJSP, etc.)
4. Quando o site pedir assinatura, o PJeOffice vai abrir a tela de certificados automaticamente
5. Selecione o certificado com a validade mais recente (os em vermelho estão expirados)
6. Digite o PIN do token quando solicitado

> **Dica:** Se tiver dois tokens (ex: eToken 5100 e GD Starsign), vá em **Configuração de certificado** dentro do PJeOffice para trocar o driver ativo.

---

## Problemas comuns

### "Não foi possível encontrar o PJe Office" no navegador

O PJeOffice precisa estar rodando em segundo plano antes de acessar o sistema do tribunal.
- Solução: Abra o PJeOffice primeiro, depois acesse o site.

### A lista de certificados aparece vazia

Causas possíveis:
1. **Token não conectado** — verifique se o token está firmemente encaixado na porta USB
2. **Driver errado** — vá em Configuração de certificado e verifique se o driver correto está selecionado
3. **Driver não instalado** — rode o script de instalação novamente

Para verificar se o sistema detecta seu token:
```bash
pkcs11-tool --module /usr/lib/libeToken.so --list-slots
```

### Certificados aparecem em vermelho

Certificados em vermelho estão **expirados**. Selecione sempre o que está em preto/azul com a data de validade mais futura. Para renovar, entre em contato com seu emissor (Certisign, OAB, Serasa, etc.).

### PJeOffice não abre / tela preta

```bash
# Rode diretamente pelo terminal para ver o erro:
cd ~/pjeoffice-pro && ./jre/bin/java -Dpjeoffice_home=$HOME/pjeoffice-pro -jar pjeoffice-pro.jar
```

---

## Estrutura do repositório

```
📦 pjeofficelinuxparaadvogados/
├── 📄 README.md          — Este guia
├── 🔧 instalar.sh        — Script de instalação automática
├── 📁 docs/
│   ├── tokens.md         — Guia detalhado por modelo de token
│   └── troubleshooting.md — Problemas e soluções
└── 📁 assets/
    └── pjeoffice-pro.png — Ícone do PJeOffice
```

---

## Contribuindo

Encontrou um token que funciona diferente? Tem uma dica que ajudou você?
Abra uma [Issue](https://github.com/vitorcanoas/pjeofficelinuxparaadvogados/issues) ou envie um Pull Request. Quanto mais advogados contribuírem, mais completo fica para todos.

---

## Licença

MIT — use, copie e compartilhe à vontade. Se ajudar algum colega advogado a migrar para o Linux, já valeu.

---

*Feito com ☕ e muita paciência por [Vitor Canoas](https://github.com/vitorcanoas)*
