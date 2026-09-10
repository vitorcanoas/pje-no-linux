#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Desinstalador (Arch Linux / Omarchy)
# Remove todos os componentes instalados pelo instalar-arch.sh
# =============================================================================

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[AVISO]${NC} %s\n" "$*"; }
log_info() { printf "[INFO] %s\n" "$*"; }

# Remove pacote pacman (AUR ou oficial) se instalado; avisa mas não aborta
# se ausente. -Rns: remove dependências órfãs e arquivos de config (.pacsave
# à parte — o pacman preserva config modificada, não some sem aviso).
remove_pkg() {
    local pkg="$1"
    if pacman -Q "$pkg" &>/dev/null; then
        sudo pacman -Rns --noconfirm "$pkg"
        log_ok "${pkg}: removido."
    else
        log_warn "${pkg}: não está instalado — ignorando."
    fi
}

# Interativo: sob 'curl | bash' toda pergunta recebe EOF e o script morreria
# calado — pior ainda num desinstalador, que remove pacotes.
if [[ ! -t 0 ]]; then
    printf "%s\n" "[ERRO] Entrada padrão não é um terminal — este desinstalador é interativo." >&2
    printf "%s\n" "  Ação: baixe o arquivo e rode de forma interativa: bash desinstalar-arch.sh" >&2
    exit 1
fi

printf "\nPJe no Linux — Desinstalador (Arch Linux / Omarchy)\n"
printf "Este script removerá todos os componentes instalados pelo instalar-arch.sh.\n\n"
printf "Deseja continuar? [s/N] "
read -r resposta || resposta=""
if [[ "${resposta,,}" != "s" ]]; then
    log_info "Desinstalação cancelada."
    exit 0
fi

printf "\n"

# === REMOVER PACOTES DO AUR ===
log_info "Removendo pacotes do AUR..."
remove_pkg google-chrome
# O instalador escolhe UM dos dois conforme o modelo do token; remove_pkg já
# ignora silenciosamente o que não estiver instalado.
remove_pkg sac-core
remove_pkg sac-core-legacy
remove_pkg sac-gui
remove_pkg pje-office
remove_pkg softplan-websigner
remove_pkg shodo

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

# Native Messaging Host — Chromium (o instalador registra em ambos quando
# o navegador correspondente está presente; o desinstalador não precisa
# checar presença, só se o manifest existe)
if [[ -f "/etc/chromium/native-messaging-hosts/br.com.softplan.webpki.json" ]]; then
    sudo rm -f "/etc/chromium/native-messaging-hosts/br.com.softplan.webpki.json"
    log_ok "Native Messaging Host (Chromium) removido."
fi

# Native Messaging Host — Microsoft Edge. O .install do pacote já limpa
# Chrome/Chromium/Edge no post_remove; isto cobre o caso de o hook não ter
# rodado (pacote removido à mão, ou instalação anterior sem o .install).
if [[ -f "/etc/opt/edge/native-messaging-hosts/br.com.softplan.webpki.json" ]]; then
    sudo rm -f "/etc/opt/edge/native-messaging-hosts/br.com.softplan.webpki.json"
    log_ok "Native Messaging Host (Edge) removido."
fi

# Native Messaging Host — Firefox
if [[ -f "$HOME/.mozilla/native-messaging-hosts/br.com.softplan.webpki.json" ]]; then
    rm -f "$HOME/.mozilla/native-messaging-hosts/br.com.softplan.webpki.json"
    log_ok "Native Messaging Host (Firefox) removido."
fi

# Módulo PKCS#11 registrado no p11-kit (aponta para a lib do SafeNet SAC)
if [[ -f "/usr/share/p11-kit/modules/safenet.module" ]]; then
    sudo rm -f "/usr/share/p11-kit/modules/safenet.module"
    log_ok "Módulo PKCS#11 (p11-kit) removido."
fi

# Atalhos Microsoft 365 PWA — sem 'local' fora de função: isso é erro de
# bash (variável ficaria implicitamente global do jeito errado e, em modo
# estrito, algumas versões de bash rejeitam 'local' fora de função).
apps_dir="$HOME/.local/share/applications"
for app in word excel powerpoint outlook; do
    desktop_file="${apps_dir}/microsoft-${app}.desktop"
    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
        log_ok "Atalho Microsoft ${app} removido."
    fi
done
update-desktop-database "$apps_dir" &>/dev/null || true

# Ícones e recursos do pje-no-linux
if [[ -d "/usr/local/share/pje-no-linux" ]]; then
    sudo rm -rf "/usr/local/share/pje-no-linux"
    log_ok "Ícones e recursos de /usr/local/share/pje-no-linux removidos."
fi

# === PERGUNTAS SEPARADAS (ações com impacto além do que o instalador criou) ===

# pcscd.socket é o daemon do leitor de smartcard — pode ser usado por outros
# programas na máquina além do PJe/e-SAJ (ex.: login por cartão, outros
# assinadores). Desabilitar é reversível, mas perguntamos à parte.
printf "\nDesabilitar o serviço pcscd.socket (leitor de smartcard)? "
printf "Isso pode afetar outros programas que dependam do leitor. [s/N] "
read -r resposta || resposta=""
if [[ "${resposta,,}" == "s" ]]; then
    sudo systemctl disable --now pcscd.socket
    log_ok "pcscd.socket desabilitado."
else
    log_info "pcscd.socket mantido."
fi

# A regra polkit libera o acesso ao leitor em sessão não-ativa para o grupo
# wheel. Não é descartável: outros assinadores e programas de smartcard na
# máquina se beneficiam dela. Por isso pergunta separada da do pcscd.
if [[ -f "/etc/polkit-1/rules.d/50-pcscd-pje.rules" ]]; then
    printf "\nRemover a regra polkit do pcscd (/etc/polkit-1/rules.d/50-pcscd-pje.rules)? "
    printf "Ela libera o leitor em sessão não-ativa e pode estar sendo usada por "
    printf "outros assinadores. [s/N] "
    read -r resposta || resposta=""
    if [[ "${resposta,,}" == "s" ]]; then
        sudo rm -f "/etc/polkit-1/rules.d/50-pcscd-pje.rules"
        log_ok "Regra polkit removida."
        sudo systemctl restart polkit 2>/dev/null || \
            log_warn "Reinicie o polkit (ou a máquina) para a remoção valer."
    else
        log_info "Regra polkit mantida."
    fi
fi

# pcsclite, ccid, opensc e p11-kit vêm do repositório oficial (não do AUR) e
# são infraestrutura genérica de smartcard/PKCS#11 — outras aplicações na
# máquina podem depender deles independente do PJe. Por isso não entram no
# remove_pkg acima; perguntamos e avisamos explicitamente do risco.
printf "\nRemover também pcsclite, ccid, opensc e p11-kit? "
printf "São pacotes do repositório oficial (não do AUR) e outros programas na "
printf "máquina podem depender deles — só remova se tiver certeza. [s/N] "
read -r resposta || resposta=""
if [[ "${resposta,,}" == "s" ]]; then
    remove_pkg pcsclite
    remove_pkg ccid
    remove_pkg opensc
    remove_pkg p11-kit
else
    log_info "pcsclite, ccid, opensc e p11-kit mantidos."
fi

# ~/.pjeoffice-pro/ guarda configuração e possivelmente certificados/chaves
# do usuário — não é algo que o instalador "criou" no sentido de artefato
# descartável, é dado pessoal. Remoção default N, com aviso explícito.
printf "\nRemover também ~/.pjeoffice-pro/ (configuração e possíveis "
printf "certificados salvos)? ATENÇÃO: pode conter dados seus. [s/N] "
read -r resposta || resposta=""
if [[ "${resposta,,}" == "s" ]]; then
    rm -rf "$HOME/.pjeoffice-pro"
    log_ok "${HOME}/.pjeoffice-pro removido."
else
    log_info "${HOME}/.pjeoffice-pro mantido."
fi

printf "\nDesinstalação concluída.\n"
