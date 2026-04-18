#!/bin/bash

# =============================================================================
# PJeOffice Pro + Certificado Digital no Linux
# Compatível com: Zorin OS 17/18, Ubuntu 22.04/24.04, Linux Mint 21/22
# Autor: Vitor Canoas | github.com/vitorcanoas/pjeofficelinuxparaadvogados
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
erro() { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${BOLD}   PJeOffice Pro + Certificado Digital — Instalador Linux      ${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""
echo -e "Este script instala e configura:"
echo -e "  • PJeOffice Pro (assinador digital do CNJ)"
echo -e "  • Driver SafeNet (tokens eToken 5100/5110 — Certisign, Serasa...)"
echo -e "  • Driver OpenSC  (tokens GD Starsign, Pronova e outros)"
echo -e "  • Dependências do sistema (pcscd, opensc, libccid)"
echo -e "  • Ícone e autostart no login"
echo ""
warn "Será necessário digitar sua senha de administrador."
echo ""
read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar..."

# =============================================================================
# 1. DEPENDÊNCIAS DO SISTEMA
# =============================================================================
info "Instalando dependências do sistema..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    pcscd \
    opensc \
    opensc-pkcs11 \
    libccid \
    libpcsclite1 \
    libnss3-tools \
    wget \
    unzip \
    curl
ok "Dependências instaladas"

# =============================================================================
# 2. DRIVER SAFENET (eToken 5100/5110 — Certisign, Serasa, Valid, Soluti)
# =============================================================================
info "Baixando driver SafeNet Authentication Client 10.8..."
SAC_URL="https://www.globalsign.com/en/safenet-drivers/USB/10.8/GlobalSign-SAC-Ubuntu-2204.zip"
SAC_ZIP="/tmp/sac_installer.zip"
SAC_DEB="safenetauthenticationclient_10.8.1050_amd64.deb"

wget -q --show-progress "$SAC_URL" -O "$SAC_ZIP"
unzip -o -q "$SAC_ZIP" -d /tmp/sac_extract/

cd /tmp/sac_extract/Ubuntu-2204/
sha1sum -c "${SAC_DEB}.sha1sum.txt" > /dev/null 2>&1 || erro "Arquivo corrompido. Tente novamente."

info "Instalando driver SafeNet..."
sudo dpkg -i "$SAC_DEB" || sudo apt-get install -f -y -qq
ok "Driver SafeNet instalado — biblioteca: /usr/lib/libeToken.so"
cd - > /dev/null

# =============================================================================
# 3. REINICIAR PCSCD
# =============================================================================
info "Reiniciando serviço de smart card..."
sudo systemctl restart pcscd
ok "pcscd reiniciado"

# =============================================================================
# 4. DOWNLOAD DO PJEOFFICE PRO
# =============================================================================
info "Baixando PJeOffice Pro..."
PJE_URL="https://pje-office.pje.jus.br/pro/pjeoffice-pro-linux_x64.zip"
PJE_ZIP="/tmp/pjeoffice-pro.zip"
PJE_DIR="$HOME/pjeoffice-pro"

wget -q --show-progress "$PJE_URL" -O "$PJE_ZIP"

info "Extraindo PJeOffice Pro..."
mkdir -p "$PJE_DIR"
unzip -o -q "$PJE_ZIP" -d "$PJE_DIR"
chmod +x "$PJE_DIR/pjeoffice-pro.sh"
chmod +x "$PJE_DIR/jre/bin/java"
ok "PJeOffice Pro extraído em $PJE_DIR"

# =============================================================================
# 5. BAIXAR ÍCONE OFICIAL
# =============================================================================
info "Baixando ícone do PJeOffice..."
wget -q "https://pje-office.pje.jus.br/pro/img/icone-pje-office-pro.png" \
    -O "$HOME/pjeoffice-pro.png" 2>/dev/null || \
wget -q "https://raw.githubusercontent.com/vitorcanoas/pjeofficelinuxparaadvogados/main/assets/pjeoffice-pro.png" \
    -O "$HOME/pjeoffice-pro.png" 2>/dev/null || true
ok "Ícone salvo"

# =============================================================================
# 6. CONFIGURAR CERTIFICADO NO PJEOFFICE
# =============================================================================
info "Configurando drivers de certificado no PJeOffice..."
mkdir -p "$HOME/.pjeoffice-pro"

cat > "$HOME/.pjeoffice-pro/pjeoffice-pro.json" << 'EOF'
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
ok "Drivers configurados"

# =============================================================================
# 7. ÍCONE NA ÁREA DE TRABALHO
# =============================================================================
info "Criando ícones..."
DESKTOP_FILE="$HOME/.local/share/applications/PJeOfficePro.desktop"
mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=PJeOffice Pro
Exec=$PJE_DIR/pjeoffice-pro.sh
Icon=$HOME/pjeoffice-pro.png
Terminal=false
Type=Application
Categories=Office;Java;
StartupWMClass=br-jus-cnj-pje-office-imp-PjeOfficeApp
EOF

# Área de trabalho
DESKTOP_PATH="$HOME/Área de trabalho"
[ -d "$HOME/Desktop" ] && DESKTOP_PATH="$HOME/Desktop"
cp "$DESKTOP_FILE" "$DESKTOP_PATH/PJeOfficePro.desktop" 2>/dev/null || true
chmod +x "$DESKTOP_PATH/PJeOfficePro.desktop" 2>/dev/null || true

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Ícones criados"

# =============================================================================
# 8. AUTOSTART NO LOGIN
# =============================================================================
info "Configurando inicialização automática..."
mkdir -p "$HOME/.config/autostart"

cat > "$HOME/.config/autostart/PJeOfficePro.desktop" << EOF
[Desktop Entry]
Name=PJeOffice Pro
Exec=$PJE_DIR/pjeoffice-pro.sh
Icon=$HOME/pjeoffice-pro.png
Terminal=false
Type=Application
Categories=Office;Java;
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
StartupWMClass=br-jus-cnj-pje-office-imp-PjeOfficeApp
EOF
ok "PJeOffice configurado para abrir automaticamente no login"

# =============================================================================
# VERIFICAÇÃO FINAL
# =============================================================================
echo ""
echo -e "${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}   Instalação concluída com sucesso!${NC}"
echo -e "${BOLD}================================================================${NC}"
echo ""
echo -e "O que foi instalado:"
echo -e "  ${GREEN}✓${NC} Driver SafeNet (eToken 5100/5110)"
echo -e "  ${GREEN}✓${NC} Driver OpenSC (outros tokens)"
echo -e "  ${GREEN}✓${NC} PJeOffice Pro em ~/pjeoffice-pro"
echo -e "  ${GREEN}✓${NC} Ícone na área de trabalho"
echo -e "  ${GREEN}✓${NC} Abre automaticamente no login"
echo ""

# Teste do token (se conectado)
if pkcs11-tool --module /usr/lib/libeToken.so --list-slots 2>/dev/null | grep -q "token label"; then
    TOKEN=$(pkcs11-tool --module /usr/lib/libeToken.so --list-slots 2>/dev/null | grep "token label" | cut -d: -f2 | xargs)
    echo -e "  ${GREEN}✓${NC} Token detectado: ${BOLD}$TOKEN${NC}"
else
    warn "Nenhum token conectado agora. Conecte seu token antes de usar o PJeOffice."
fi

echo ""
echo -e "  Para usar: clique em ${BOLD}PJeOffice Pro${NC} na área de trabalho"
echo -e "  Dúvidas: github.com/vitorcanoas/pjeofficelinuxparaadvogados"
echo ""

# =============================================================================
# 9. WEBSIGNER (eSAJ / TJSP e outros tribunais SAJ)
# =============================================================================
info "Instalando Web Signer (eSAJ/TJSP)..."

WEBSIGNER_URL="https://websigner.softplan.com.br/Downloads/2.9.5/webpki-chrome-64-deb"
wget -q --show-progress "$WEBSIGNER_URL" -O /tmp/websigner.deb

sudo dpkg -i /tmp/websigner.deb || sudo apt-get install -f -y -qq

# Configurar Native Messaging para Chrome .deb
sudo mkdir -p /etc/opt/chrome/native-messaging-hosts/
sudo cp /opt/softplan-websigner/manifest.json \
    /etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json

ok "Web Signer instalado"
echo ""
warn "Para o eSAJ funcionar, após instalar:"
echo "  1. Instale a extensão Web Signer no Chrome:"
echo "     https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol"
echo "  2. Abra o Web Signer → Configurações → Cripto Dispositivos"
echo "  3. No campo 'Nome do arquivo SO' digite: libeToken.so"
echo "  4. Clique em + para adicionar"
