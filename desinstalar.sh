#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Desinstalador
# Remove todos os componentes instalados pelo instalar.sh
# =============================================================================

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly RED='\033[0;31m'

log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[AVISO]${NC} %s\n" "$*"; }
log_info()  { printf "[INFO] %s\n" "$*"; }
log_error() { printf "${RED}[ERRO]${NC} %s\n" "$*" >&2; }

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

mostrar_ajuda() {
    cat <<'AJUDA'
PJe no Linux — desinstalador para Ubuntu, Zorin OS, Linux Mint e Debian

USO
    bash desinstalar.sh [opções]

O QUE ELE FAZ
    Remove os componentes instalados por instalar.sh: Chrome, SafeNet SAC,
    SafeSign IC, PJeOffice Pro, Web Signer, Antigravity, o Native Messaging
    Host e as configurações de sistema criadas pelo instalador. Pacotes que
    não estiverem instalados são ignorados sem erro.

OPÇÕES
    -y, --yes     Pula a confirmação inicial.
    -h, --help    Mostra esta ajuda e sai, sem remover nada.

USA ARCH, OMARCHY, ENDEAVOUROS, MANJARO OU CACHYOS?
    Rode: bash desinstalar-arch.sh

PIN DO CERTIFICADO
    Nenhum script deste repositório pede, lê, grava ou registra o seu PIN.
AJUDA
}

ASSUME_YES=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) mostrar_ajuda; exit 0 ;;
        -y|--yes)  ASSUME_YES=true; shift ;;
        *)
            log_error "Opção desconhecida: $1"
            log_error "  Ação: bash desinstalar.sh --help"
            exit 1
            ;;
    esac
done
readonly ASSUME_YES

# Guard-rail cruzado: quem rodou o desinstalador errado descobre agora, com o
# comando certo na tela — e não depois de 'dpkg: command not found'.
DETECTAR_DISTRO_LIB="${SCRIPT_DIR}/lib/detectar-distro.sh"
if [[ -r "$DETECTAR_DISTRO_LIB" ]]; then
    # shellcheck source=lib/detectar-distro.sh
    source "$DETECTAR_DISTRO_LIB"
    detectar_distro
    exigir_familia debian "desinstalar-arch.sh"
elif ! command -v apt-get &>/dev/null; then
    log_error "'apt-get' não encontrado — este script é para Ubuntu, Zorin, Mint e Debian."
    log_error "  Em Arch, Omarchy, EndeavourOS, Manjaro ou CachyOS use: bash desinstalar-arch.sh"
    exit 1
fi

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
if $ASSUME_YES; then
    log_info "--yes informado: confirmação dispensada."
else
    printf "Deseja continuar? [s/N] "
    read -r resposta
    if [[ "${resposta,,}" != "s" ]]; then
        log_info "Desinstalação cancelada."
        exit 0
    fi
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
