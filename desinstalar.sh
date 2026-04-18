#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Desinstalador
# Remove todos os componentes instalados pelo instalar.sh
# =============================================================================

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[AVISO]${NC} %s\n" "$*"; }
log_info() { printf "[INFO] %s\n" "$*"; }

# Remove pacote dpkg se instalado; avisa mas não aborta se ausente
remove_pkg() {
    local pkg="$1"
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        sudo dpkg -r "$pkg"
        log_ok "${pkg}: removido."
    else
        log_warn "${pkg}: não está instalado — ignorando."
    fi
}

printf "\nPJe no Linux — Desinstalador\n"
printf "Este script removerá todos os componentes instalados pelo instalar.sh.\n\n"
printf "Deseja continuar? [s/N] "
read -r resposta
if [[ "${resposta,,}" != "s" ]]; then
    log_info "Desinstalação cancelada."
    exit 0
fi

printf "\n"

# === REMOVER PACOTES ===
log_info "Removendo pacotes dpkg..."
remove_pkg google-chrome-stable
remove_pkg safenetauthenticationclient
remove_pkg safesign
remove_pkg pjeoffice-pro
remove_pkg webpki-chrome
remove_pkg antigravity

# === REMOVER CONFIGURAÇÕES ===
log_info "Removendo configurações do sistema..."

# Autostart PJeOffice
if [[ -f "$HOME/.config/autostart/pjeoffice-pro.desktop" ]]; then
    rm -f "$HOME/.config/autostart/pjeoffice-pro.desktop"
    log_ok "Autostart PJeOffice removido."
fi

# Native Messaging Host — Chrome
if [[ -f "/etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json" ]]; then
    sudo rm -f "/etc/opt/chrome/native-messaging-hosts/br.com.softplan.webpki.json"
    log_ok "Native Messaging Host (Chrome) removido."
fi

# Native Messaging Host — Firefox
if [[ -f "$HOME/.mozilla/native-messaging-hosts/br.com.softplan.webpki.json" ]]; then
    rm -f "$HOME/.mozilla/native-messaging-hosts/br.com.softplan.webpki.json"
    log_ok "Native Messaging Host (Firefox) removido."
fi

# Atalhos Microsoft 365 PWA
local_apps="$HOME/.local/share/applications"
for app in word excel powerpoint outlook; do
    desktop_file="${local_apps}/microsoft-${app}.desktop"
    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
        log_ok "Atalho Microsoft ${app} removido."
    fi
done

# Ícones e recursos do pje-no-linux
if [[ -d "/usr/local/share/pje-no-linux" ]]; then
    sudo rm -rf "/usr/local/share/pje-no-linux"
    log_ok "Ícones e recursos de /usr/local/share/pje-no-linux removidos."
fi

# Atalho Super+Shift+S
if command -v gsettings &>/dev/null; then
    gsettings reset org.gnome.shell.keybindings show-screenshot-ui 2>/dev/null \
        && log_ok "Atalho Super+Shift+S revertido ao padrão do sistema."
fi

printf "\nDesinstalação concluída.\n"
