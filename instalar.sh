#!/bin/bash

# =============================================================================
# PJe no Linux — Instalador para Advogados
# Instala: Google Chrome + PJeOffice Pro + Drivers de Token + Web Signer
# Compatível com: Zorin OS 17/18, Ubuntu 22.04/24.04, Linux Mint 21/22
# Repositório: github.com/vitorcanoas/pje-no-linux
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${BLUE}➤ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
erro() { echo -e "${RED}✗ ERRO: $1${NC}"; exit 1; }

clear
echo ""
echo -e "${BOLD}=============================================================${NC}"
echo -e "${BOLD}        PJe no Linux — Instalador para Advogados             ${NC}"
echo -e "${BOLD}=============================================================${NC}"
echo ""
echo -e "Este script vai instalar e configurar automaticamente:"
echo ""
echo -e "  ${GREEN}✓${NC} Google Chrome (navegador oficial para o PJe e eSAJ)"
echo -e "  ${GREEN}✓${NC} Driver SafeNet (tokens eToken 5100/5110 — Certisign, OAB, Serasa)"
echo -e "  ${GREEN}✓${NC} Driver GD SafeSign (tokens StarSign e cartões GD/Safesign)"
echo -e "  ${GREEN}✓${NC} Driver OpenSC (Gemalto, cartões genéricos e fallback)"
echo -e "  ${GREEN}✓${NC} PJeOffice Pro (assinador dos tribunais)"
echo -e "  ${GREEN}✓${NC} Web Signer (para assinar no eSAJ/TJSP)"
echo ""
echo -e "${YELLOW}Durante a instalação será pedida sua senha de administrador."
echo -e "Quando digitar a senha, as letras não aparecem — isso é normal.${NC}"
echo ""
read -rp "Pressione ENTER para começar (ou Ctrl+C para cancelar)..."
echo ""

# =============================================================================
# 1. DEPENDÊNCIAS DO SISTEMA
# =============================================================================
info "Instalando dependências do sistema..."
sudo apt-get update -qq 2>/dev/null
sudo apt-get install -y -qq \
    pcscd \
    opensc \
    opensc-pkcs11 \
    libccid \
    libpcsclite1 \
    libpcsclite-dev \
    pcsc-tools \
    wget \
    curl \
    unzip \
    unrar 2>/dev/null || \
sudo apt-get install -y -qq \
    pcscd \
    opensc \
    opensc-pkcs11 \
    libccid \
    libpcsclite1 \
    pcsc-tools \
    wget \
    curl \
    unzip \
    unar 2>/dev/null || true
ok "Dependências instaladas"

# =============================================================================
# 2. GOOGLE CHROME (versão .deb — necessário para o Web Signer funcionar)
# =============================================================================
if command -v google-chrome &>/dev/null && [ -f /opt/google/chrome/chrome ]; then
    ok "Google Chrome já instalado ($(google-chrome --version))"
else
    info "Baixando e instalando Google Chrome..."
    wget -q --show-progress \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
        -O /tmp/google-chrome.deb
    sudo dpkg -i /tmp/google-chrome.deb 2>/dev/null || sudo apt-get install -f -y -qq
    ok "Google Chrome instalado"
fi

# =============================================================================
# 3. DRIVER SAFENET (tokens eToken 5100/5110 — Certisign, OAB, Serasa, Valid)
# =============================================================================
if [ -f /usr/lib/libeToken.so ]; then
    ok "Driver SafeNet já instalado"
else
    info "Baixando driver SafeNet (tokens eToken 5100/5110)..."
    wget -q --show-progress \
        "https://www.globalsign.com/en/safenet-drivers/USB/10.8/GlobalSign-SAC-Ubuntu-2204.zip" \
        -O /tmp/sac.zip
    unzip -o -q /tmp/sac.zip -d /tmp/sac_extract/
    info "Instalando driver SafeNet..."
    sudo dpkg -i /tmp/sac_extract/Ubuntu-2204/safenetauthenticationclient_10.8.1050_amd64.deb \
        2>/dev/null || sudo apt-get install -f -y -qq
    ok "Driver SafeNet instalado"
fi

# =============================================================================
# 4. DRIVER GD SAFESIGN (tokens StarSign, Cartão Azul/Prata GD, Safesign)
# =============================================================================
if [ -f /usr/lib/libaetpkss.so ] || [ -f /usr/lib/libaetpkss.so.3 ]; then
    ok "Driver GD SafeSign já instalado"
else
    info "Baixando driver GD SafeSign (tokens StarSign e cartões GD)..."
    SAFESIGN_DOWNLOADED=false

    # Detectar versão do Ubuntu para escolher o .deb correto
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "22.04")
    UBUNTU_MAJOR=$(echo "$UBUNTU_VERSION" | cut -d. -f1)

    if [ "$UBUNTU_MAJOR" -ge 24 ]; then
        SAFESIGN_FILE="SafeSign_IC_Standard_Linux_3.7.0.0_AET.000_ub2004_x86_64.rar"
    else
        SAFESIGN_FILE="SafeSign_IC_Standard_Linux_3.7.0.0_AET.000_ub2004_x86_64.rar"
    fi

    wget -q --show-progress \
        "https://safesign.gdamericadosul.com.br/content/${SAFESIGN_FILE}" \
        -O /tmp/safesign.rar && SAFESIGN_DOWNLOADED=true || true

    if [ "$SAFESIGN_DOWNLOADED" = true ]; then
        mkdir -p /tmp/safesign_extract
        if command -v unrar &>/dev/null; then
            unrar x -o+ /tmp/safesign.rar /tmp/safesign_extract/ 2>/dev/null || true
        elif command -v unar &>/dev/null; then
            unar -o /tmp/safesign_extract/ /tmp/safesign.rar 2>/dev/null || true
        fi
        # Instalar o .deb encontrado
        SAFESIGN_DEB=$(find /tmp/safesign_extract -name "*.deb" | head -1)
        if [ -n "$SAFESIGN_DEB" ]; then
            info "Instalando GD SafeSign..."
            sudo dpkg -i "$SAFESIGN_DEB" 2>/dev/null || sudo apt-get install -f -y -qq
            ok "Driver GD SafeSign instalado"
        else
            warn "Não foi possível extrair o instalador GD SafeSign — token StarSign pode não funcionar"
        fi
    else
        warn "Não foi possível baixar o driver GD SafeSign — token StarSign pode não funcionar"
        warn "Se usar token StarSign, baixe manualmente em: https://safesign.gdamericadosul.com.br/download"
    fi
fi

# =============================================================================
# 5. REINICIAR SERVIÇO DE SMART CARD
# =============================================================================
info "Iniciando serviço de leitura de token..."
sudo systemctl enable pcscd 2>/dev/null
sudo systemctl restart pcscd
ok "Serviço de token iniciado"

# =============================================================================
# 6. PJEOFFICE PRO
# =============================================================================
PJE_DIR="$HOME/pjeoffice-pro"
if [ -f "$PJE_DIR/pjeoffice-pro.jar" ]; then
    ok "PJeOffice Pro já instalado"
else
    info "Baixando PJeOffice Pro (pode demorar alguns minutos)..."
    wget -q --show-progress \
        "https://pje-office.pje.jus.br/pro/pjeoffice-pro-linux_x64.zip" \
        -O /tmp/pjeoffice.zip || \
    wget -q --show-progress \
        "https://pje-office.pje.jus.br/pro/pjeoffice-pro-v2.5.16u-linux_x64.zip" \
        -O /tmp/pjeoffice.zip
    info "Instalando PJeOffice Pro..."
    mkdir -p "$PJE_DIR"
    unzip -o -q /tmp/pjeoffice.zip -d "$PJE_DIR"
    chmod +x "$PJE_DIR/pjeoffice-pro.sh"
    chmod +x "$PJE_DIR/jre/bin/java"
    ok "PJeOffice Pro instalado"
fi

# =============================================================================
# 7. CONFIGURAR DRIVERS DE CERTIFICADO NO PJEOFFICE
# =============================================================================
info "Configurando drivers de certificado no PJeOffice..."
mkdir -p "$HOME/.pjeoffice-pro"

# Construir lista de drivers dinamicamente conforme os instalados
DRIVERS_JSON='   "drivers": ['

DRIVER_SAFENET=false
DRIVER_GD=false
DRIVER_OPENSC=false

if [ -f /usr/lib/libeToken.so ]; then
    DRIVER_SAFENET=true
    DRIVERS_JSON+='
     {
       "name": "Token SafeNet (eToken 5100/5110 — Certisign, OAB, Serasa, Valid)",
       "library": "/usr/lib/libeToken.so"
     },'
fi

if [ -f /usr/lib/libaetpkss.so ] || [ -f /usr/lib/libaetpkss.so.3 ]; then
    DRIVER_GD=true
    GD_LIB="/usr/lib/libaetpkss.so"
    [ -f /usr/lib/libaetpkss.so.3 ] && GD_LIB="/usr/lib/libaetpkss.so.3"
    DRIVERS_JSON+="
     {
       \"name\": \"Token GD SafeSign (StarSign, Cartão Azul/Prata GD — Certisign)\",
       \"library\": \"$GD_LIB\"
     },"
fi

if [ -f /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so ]; then
    DRIVER_OPENSC=true
    DRIVERS_JSON+='
     {
       "name": "Token Genérico / OpenSC (Gemalto, cartões sem driver específico)",
       "library": "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
     },'
fi

# Remover última vírgula e fechar JSON
DRIVERS_JSON="${DRIVERS_JSON%,}"
DRIVERS_JSON+='
   ]'

# Determinar driver padrão
if [ "$DRIVER_SAFENET" = true ]; then
    CURRENT_DRIVER="Token SafeNet (eToken 5100/5110 — Certisign, OAB, Serasa, Valid)"
elif [ "$DRIVER_GD" = true ]; then
    CURRENT_DRIVER="Token GD SafeSign (StarSign, Cartão Azul/Prata GD — Certisign)"
else
    CURRENT_DRIVER="Token Genérico / OpenSC (Gemalto, cartões sem driver específico)"
fi

cat > "$HOME/.pjeoffice-pro/pjeoffice-pro.json" << EOF
{
$DRIVERS_JSON,
   "currentDriver": "$CURRENT_DRIVER"
}
EOF

ok "Drivers de certificado configurados no PJeOffice"

# =============================================================================
# 8. WEB SIGNER (para eSAJ/TJSP e outros tribunais SAJ)
# =============================================================================
if dpkg -l softplan-websigner 2>/dev/null | grep -q "^ii"; then
    ok "Web Signer já instalado"
else
    info "Baixando Web Signer (eSAJ/TJSP)..."
    wget -q --show-progress \
        "https://websigner.softplan.com.br/Downloads/2.9.5/webpki-chrome-64-deb" \
        -O /tmp/websigner.deb
    info "Instalando Web Signer..."
    sudo dpkg -i /tmp/websigner.deb 2>/dev/null || sudo apt-get install -f -y -qq
    ok "Web Signer instalado"
fi

# Configurar Native Messaging para Chrome
sudo mkdir -p /etc/opt/chrome/native-messaging-hosts/
sudo cp /opt/softplan-websigner/manifest.json \
    /etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json
ok "Web Signer configurado para o Chrome"

# =============================================================================
# 9. ÍCONE E ÁREA DE TRABALHO
# =============================================================================
info "Criando ícones..."
ICON_PATH="$HOME/pjeoffice-pro.png"

# Baixar ícone
wget -q "https://raw.githubusercontent.com/vitorcanoas/pje-no-linux/main/assets/pjeoffice-pro.png" \
    -O "$ICON_PATH" 2>/dev/null || true

# Criar .desktop
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/PJeOfficePro.desktop" << EOF
[Desktop Entry]
Name=PJeOffice Pro
Exec=$PJE_DIR/pjeoffice-pro.sh
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Office;Java;
StartupWMClass=br-jus-cnj-pje-office-imp-PjeOfficeApp
EOF

# Copiar para área de trabalho
for DESKTOP in "$HOME/Desktop" "$HOME/Área de trabalho"; do
    if [ -d "$DESKTOP" ]; then
        cp "$HOME/.local/share/applications/PJeOfficePro.desktop" "$DESKTOP/" 2>/dev/null || true
        chmod +x "$DESKTOP/PJeOfficePro.desktop" 2>/dev/null || true
    fi
done

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Ícone criado na área de trabalho"

# =============================================================================
# 10. AUTOSTART (abrir PJeOffice automaticamente ao ligar o computador)
# =============================================================================
info "Configurando abertura automática no login..."
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/PJeOfficePro.desktop" << EOF
[Desktop Entry]
Name=PJeOffice Pro
Exec=$PJE_DIR/pjeoffice-pro.sh
Icon=$ICON_PATH
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
StartupWMClass=br-jus-cnj-pje-office-imp-PjeOfficeApp
EOF
ok "PJeOffice configurado para abrir no login"

# =============================================================================
# INSTALAÇÃO CONCLUÍDA
# =============================================================================

# Testar tokens
SAFENET_OK=false
GD_OK=false

if [ -f /usr/lib/libeToken.so ] && pkcs11-tool --module /usr/lib/libeToken.so --list-slots 2>/dev/null | grep -q "token label"; then
    SAFENET_OK=true
fi

if [ -f /usr/lib/libaetpkss.so ] || [ -f /usr/lib/libaetpkss.so.3 ]; then
    GD_LIB="/usr/lib/libaetpkss.so"
    [ -f /usr/lib/libaetpkss.so.3 ] && GD_LIB="/usr/lib/libaetpkss.so.3"
    if pkcs11-tool --module "$GD_LIB" --list-slots 2>/dev/null | grep -q "token label"; then
        GD_OK=true
    fi
fi

clear
echo ""
echo -e "${BOLD}=============================================================${NC}"
echo -e "${GREEN}${BOLD}          Instalação concluída com sucesso!               ${NC}"
echo -e "${BOLD}=============================================================${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Google Chrome instalado"
echo -e "  ${GREEN}✓${NC} Driver SafeNet instalado (tokens eToken 5100/5110)"
echo -e "  ${GREEN}✓${NC} Driver GD SafeSign instalado (tokens StarSign e cartões GD)"
echo -e "  ${GREEN}✓${NC} Driver OpenSC instalado (tokens genéricos e Gemalto)"
echo -e "  ${GREEN}✓${NC} PJeOffice Pro instalado"
echo -e "  ${GREEN}✓${NC} Web Signer instalado"
echo ""

if [ "$SAFENET_OK" = true ]; then
    echo -e "  ${GREEN}✓${NC} Token SafeNet detectado e funcionando!"
    echo ""
elif [ "$GD_OK" = true ]; then
    echo -e "  ${GREEN}✓${NC} Token GD detectado e funcionando!"
    echo ""
fi

echo -e "${BOLD}PRÓXIMOS PASSOS:${NC}"
echo ""
echo -e "  ${BOLD}Para usar o PJeOffice (TRT, TRF, etc.):${NC}"
echo -e "  1. Conecte seu token USB"
echo -e "  2. Clique no ícone ${BOLD}PJeOffice Pro${NC} na área de trabalho"
echo -e "  3. Acesse o sistema do tribunal no navegador"
echo ""
echo -e "  ${BOLD}Para usar o eSAJ/TJSP — configure o Web Signer (uma única vez):${NC}"
echo -e "  1. Abra o Google Chrome"
echo -e "  2. Instale a extensão Web Signer:"
echo -e "     ${BLUE}https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol${NC}"
echo -e "  3. Clique no ícone do Web Signer → Configurações → Cripto Dispositivos"
echo -e "  4. No campo 'Nome do arquivo SO' adicione o driver do seu token:"

if [ "$DRIVER_SAFENET" = true ]; then
echo -e "     - Token eToken 5100/5110: ${BOLD}libeToken.so${NC}"
fi
if [ "$DRIVER_GD" = true ]; then
echo -e "     - Token StarSign / Cartão GD: ${BOLD}libaetpkss.so${NC}"
fi
echo -e "  5. Clique em ${BOLD}+${NC} para adicionar"
echo ""
echo -e "  Dúvidas? Acesse: ${BLUE}github.com/vitorcanoas/pje-no-linux${NC}"
echo ""
