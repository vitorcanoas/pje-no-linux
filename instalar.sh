#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Instalador de Componentes
# Instala: Google Chrome, SafeNet SAC, SafeSign IC, PJeOffice Pro,
#          Web Signer, Antigravity IDE e Microsoft 365 PWA
#
# Uso: bash instalar.sh
# Requisitos: Ubuntu 22.04/24.04, Zorin OS 17/18, Linux Mint 21-22, Debian 12+
#             Arquitetura amd64 | Bash 5.0+
# =============================================================================

# === CONFIGURAÇÃO — edite aqui para atualizar versões ===
readonly SAC_VERSION="10.8.1050"
readonly SAFESIGN_VERSION="4.6.0.0"
readonly PJEOFFICE_VERSION="v2.5.16u"
readonly WEBSIGNER_VERSION="2.12.1"

# Localização do script (necessário para acessar assets/icons/)
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# URLs — construídas a partir das variáveis de versão acima
# Chrome: instalado via repositório apt oficial (GPG verificado pelo apt automaticamente)
readonly CHROME_APT_KEY_URL="https://dl.google.com/linux/linux_signing_key.pub"
readonly CHROME_APT_KEYRING="/usr/share/keyrings/google-chrome.gpg"
readonly CHROME_APT_SOURCE="deb [arch=amd64 signed-by=${CHROME_APT_KEYRING}] https://dl.google.com/linux/chrome/deb/ stable main"
readonly SAC_URL="https://www.globalsign.com/en/safenet-drivers/USB/10.8/GlobalSign-SAC-Ubuntu-2204.zip"
readonly SAFESIGN_URL="https://safesign.gdamericadosul.com.br/content/SafeSign%20IC%20Standard%20Linux%20ub2204%20${SAFESIGN_VERSION}-AET.000.zip"
readonly PJEOFFICE_URL="https://pje-office.pje.jus.br/pro/pjeoffice-pro-${PJEOFFICE_VERSION}-linux_x64.zip"
readonly WEBSIGNER_URL="https://websigner.softplan.com.br/Downloads/${WEBSIGNER_VERSION}/webpki-chrome-64-deb"
readonly ANTIGRAVITY_URL="https://antigravity.google/download/linux"

# Hashes SHA256 — pré-calculados offline e commitados no repositório
# Chrome não tem hash aqui: verificação GPG é feita pelo apt (mais seguro)
# Para os demais: execute ./atualizar-hashes.sh para calcular e atualizar
readonly SAC_HASH="0583c3e5478a5251803af16f0bbd7d2a4e48d20188deb9dc6178456ec8d20316"
readonly SAFESIGN_HASH="69307586b99f13bfd67bece4629ac84c920f6f317b5c6b91e2afa79977508f22"
readonly PJEOFFICE_HASH="6087391759c7cba11fb5ef815fe8be91713b46a8607c12eb664a9d9a6882c4c7"
readonly WEBSIGNER_HASH="5da8fd36f1371f52bbaebede75fade1928f09cff2dd605b8da5663c6da505379"
# Antigravity: snap preferido (sandbox); .deb como fallback
readonly ANTIGRAVITY_SNAP="antigravity"
readonly ANTIGRAVITY_HASH="ba16cb265fb823c8b738680e1497dfeb7990d4951566beb828d5b3547564f28b"

# Log — captura toda saída (inclusive tela de consentimento)
LOG_FILE="$HOME/pje-install-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_FILE
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Diretório temporário — criado em main() APÓS consentimento do usuário
TMPDIR_WORK=""
cleanup() {
    [[ -n "${TMPDIR_WORK}" ]] && rm -rf "${TMPDIR_WORK}"
}
trap cleanup EXIT

# Status de instalação por componente
declare -A INSTALL_STATUS

# Presença de Firefox — detectada em check_dependencies()
FIREFOX_PRESENT=false

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log_error() { printf "${RED}[ERRO]${NC} %s\n" "$*" >&2; }
log_warn()  { printf "${YELLOW}[AVISO]${NC} %s\n" "$*"; }
log_info()  { printf "[INFO] %s\n" "$*"; }
log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$*"; }

# Verifica instalação via dpkg -l e registra em INSTALL_STATUS
# Uso: verify_installed <id> <pacote-dpkg>
verify_installed() {
    local id="$1" pkg="$2"
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        INSTALL_STATUS["$id"]="ok"
        log_ok "${pkg}: instalado e verificado via dpkg."
    else
        INSTALL_STATUS["$id"]="fail"
        log_warn "${pkg}: instalação não confirmada — verifique o log em ${LOG_FILE}."
    fi
}

# Baixa e verifica SHA256 antes de qualquer uso
# Uso: download_and_verify <url> <nome-arquivo> <sha256-esperado>
download_and_verify() {
    local url="$1" filename="$2" expected_hash="$3"

    if [[ "$expected_hash" == PLACEHOLDER* ]]; then
        log_warn "${filename}: verificação SHA256 pendente — download via HTTPS."
    fi

    log_info "Baixando ${filename}..."
    if ! wget --timeout=30 --tries=3 --retry-on-http-error=503,429 \
              -O "${TMPDIR_WORK}/${filename}" "$url"; then
        log_error "${filename}: falha no download."
        log_error "  URL: ${url}"
        log_error "  Ação: verifique a conexão e tente novamente. Se o erro persistir, verifique se a URL ainda é válida."
        return 1
    fi

    if [[ "$expected_hash" != PLACEHOLDER* ]]; then
        local actual_hash
        actual_hash="$(sha256sum "${TMPDIR_WORK}/${filename}" | cut -d' ' -f1)"
        if [[ "$actual_hash" != "$expected_hash" ]]; then
            log_error "${filename}: hash SHA256 inválido — arquivo corrompido ou adulterado."
            log_error "  Esperado : ${expected_hash}"
            log_error "  Obtido   : ${actual_hash}"
            log_error "  Ação     : não instale este arquivo. Contate o mantenedor do script."
            exit 1
        fi
        log_ok "Hash SHA256 verificado: ${filename}"
    fi
}

# Tenta instalar via snap (sandbox nativo); fallback para .deb com SHA256
# Uso: install_snap_or_deb <id> <snap-name> <deb-url> <deb-file> <deb-hash> <dpkg-pkg>
install_snap_or_deb() {
    local id="$1" snap_name="$2" deb_url="$3" deb_file="$4" deb_hash="$5" dpkg_pkg="$6"

    if command -v snap &>/dev/null && snap info "$snap_name" &>/dev/null 2>&1; then
        log_info "${snap_name}: versão snap encontrada — instalando com sandbox..."
        if sudo snap install "$snap_name" --classic 2>/dev/null \
           || sudo snap install "$snap_name" 2>/dev/null; then
            INSTALL_STATUS["$id"]="ok"
            log_ok "${snap_name}: instalado via snap (sandbox ativo)."
            return 0
        fi
        log_warn "${snap_name}: snap falhou — usando .deb como fallback..."
    else
        log_info "${snap_name}: não disponível no snap — instalando via .deb..."
    fi

    download_and_verify "$deb_url" "$deb_file" "$deb_hash"
    sudo dpkg -i "${TMPDIR_WORK}/${deb_file}" || sudo apt-get install -f -y -q
    verify_installed "$id" "$dpkg_pkg"
}

# =============================================================================
# DETECÇÃO DE AMBIENTE (US2)
# =============================================================================

check_environment() {
    log_info "Verificando ambiente..."

    local arch
    arch="$(dpkg --print-architecture)"
    if [[ "$arch" != "amd64" ]]; then
        log_error "Arquitetura não suportada: este script suporta apenas amd64."
        log_error "  Detectado: ${arch}"
        log_error "  Ação: execute em uma máquina com processador Intel/AMD de 64 bits."
        exit 1
    fi

    local distro version
    distro="$(lsb_release -is 2>/dev/null || echo 'Unknown')"
    version="$(lsb_release -rs 2>/dev/null || echo '0')"

    local supported=false
    case "$distro" in
        Ubuntu)
            case "$version" in
                22.04|24.04) supported=true ;;
            esac
            ;;
        Zorin)
            case "$version" in
                17|17.*|18|18.*) supported=true ;;
            esac
            ;;
        Linuxmint)
            case "$version" in
                21|21.1|21.2|21.3|22) supported=true ;;
            esac
            ;;
        Debian)
            case "$version" in
                12|13) supported=true ;;
            esac
            ;;
    esac

    if ! $supported; then
        log_warn "Sistema não homologado: ${distro} ${version}"
        log_warn "Sistemas suportados: Ubuntu 22.04/24.04 | Zorin OS 17/18 | Linux Mint 21-22 | Debian 12/13"
        printf "\nDeseja continuar por sua conta e risco? [s/N] "
        local resposta
        read -r resposta
        if [[ "${resposta,,}" != "s" ]]; then
            log_info "Instalação cancelada pelo usuário."
            exit 0
        fi
    fi

    log_ok "Ambiente: ${distro} ${version} (amd64)"
}

check_dependencies() {
    log_info "Verificando dependências..."

    local dep
    for dep in wget sha256sum dpkg lsb_release unzip; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Dependência ausente: '${dep}'."
            log_error "  Ação: sudo apt-get install -y ${dep}"
            exit 1
        fi
    done

    # Detectar Firefox (todas as formas de instalação conhecidas)
    if command -v firefox &>/dev/null \
        || snap list firefox &>/dev/null 2>&1 \
        || dpkg -l firefox 2>/dev/null | grep -q '^ii' \
        || dpkg -l firefox-esr 2>/dev/null | grep -q '^ii'; then
        FIREFOX_PRESENT=true
        log_info "Firefox detectado — Native Messaging Host será configurado para Firefox."
    fi

    # Detectar Chrome via Snap (incompatível com Native Messaging Host)
    if snap list google-chrome &>/dev/null 2>&1; then
        log_warn "Chrome detectado via Snap."
        log_warn "O Chrome Snap não suporta Native Messaging Host — o Web Signer não funcionará corretamente."
        printf "\nDeseja remover o Chrome Snap e instalar o .deb oficial? [s/N] "
        local resposta
        read -r resposta
        if [[ "${resposta,,}" == "s" ]]; then
            log_info "Removendo Chrome Snap..."
            sudo snap remove google-chrome
            log_ok "Chrome Snap removido. O .deb será instalado a seguir."
        else
            log_warn "Chrome Snap mantido. O Web Signer pode não funcionar corretamente."
        fi
    fi

    log_ok "Dependências verificadas."
}

# =============================================================================
# RESUMO E CONSENTIMENTO (US5)
# =============================================================================

show_summary_and_confirm() {
    local distro version
    distro="$(lsb_release -is 2>/dev/null || echo 'Linux')"
    version="$(lsb_release -rs 2>/dev/null || echo '')"

    printf "\n${BOLD}"
    printf "╔═══════════════════════════════════════════════════════╗\n"
    printf "║       PJe no Linux — Instalador de Componentes        ║\n"
    printf "╚═══════════════════════════════════════════════════════╝${NC}\n\n"
    printf "  SO detectado : %s %s (amd64)\n" "$distro" "$version"
    printf "  Log          : %s\n\n" "$LOG_FILE"
    printf "  Componentes a instalar:\n"
    printf "    • Google Chrome (stable)             — dl.google.com\n"
    printf "    • SafeNet SAC %-8s              — [PROPRIETÁRIO] via GlobalSign*\n" "$SAC_VERSION"
    printf "    • SafeSign IC %-8s              — [PROPRIETÁRIO] aeteurope.com\n" "$SAFESIGN_VERSION"
    printf "    • PJeOffice Pro %-8s            — pje.jus.br (CNJ oficial)\n" "$PJEOFFICE_VERSION"
    printf "    • Web Signer %-8s              — [PROPRIETÁRIO] softplan.com.br\n" "$WEBSIGNER_VERSION"
    printf "    • Antigravity IDE                    — antigravity.google\n"
    printf "    • Microsoft 365 PWA (Word, Excel, PowerPoint, Outlook)\n\n"
    printf "  ${YELLOW}⚠  SafeNet SAC, SafeSign e Web Signer são software proprietário.${NC}\n"
    printf "     A instalação implica aceite dos termos de uso de cada fabricante.\n\n"
    printf "  ${YELLOW}*  SafeNet SAC é distribuído via parceiro GlobalSign (não é o site${NC}\n"
    printf "     ${YELLOW}oficial da Thales/SafeNet). O download oficial requer cadastro.${NC}\n\n"

    printf "Deseja continuar? [s/N] "
    local resposta
    read -r resposta
    if [[ "${resposta,,}" != "s" ]]; then
        log_info "Instalação cancelada pelo usuário."
        exit 0
    fi
    printf "\n"
}

# =============================================================================
# INSTALAÇÃO DOS COMPONENTES (US1)
# =============================================================================

install_chrome() {
    log_info "=== Google Chrome (via apt + GPG) ==="
    # Chrome NÃO usa snap: snap Chrome é incompatível com Native Messaging Host (Web Signer)
    # Instalação via repositório apt oficial — GPG verificado automaticamente pelo apt

    if [[ ! -f "$CHROME_APT_KEYRING" ]]; then
        log_info "Importando chave GPG do Google..."
        wget --timeout=30 --tries=3 -qO- "$CHROME_APT_KEY_URL" \
            | sudo gpg --dearmor -o "$CHROME_APT_KEYRING"
        log_ok "Chave GPG do Google importada."
    fi

    if [[ ! -f "/etc/apt/sources.list.d/google-chrome.list" ]]; then
        echo "$CHROME_APT_SOURCE" \
            | sudo tee "/etc/apt/sources.list.d/google-chrome.list" > /dev/null
    fi

    sudo apt-get update -qq
    sudo apt-get install -y -q google-chrome-stable
    verify_installed "chrome" "google-chrome-stable"
}

install_sac() {
    log_info "=== SafeNet Authentication Client (SAC ${SAC_VERSION}) ==="
    download_and_verify \
        "$SAC_URL" \
        "GlobalSign-SAC-Ubuntu-2204.zip" \
        "$SAC_HASH"

    local sac_dir="${TMPDIR_WORK}/sac"
    mkdir -p "$sac_dir"
    unzip -q "${TMPDIR_WORK}/GlobalSign-SAC-Ubuntu-2204.zip" -d "$sac_dir"

    local deb_file
    deb_file="$(find "$sac_dir" -name "safenetauthenticationclient_*.deb" | head -1)"
    if [[ -z "$deb_file" ]]; then
        log_error "SAC: arquivo .deb não encontrado dentro do zip."
        log_error "  URL usada: ${SAC_URL}"
        log_error "  Ação: verifique o conteúdo do zip ou baixe manualmente do portal Thales."
        INSTALL_STATUS["sac"]="fail"
        return
    fi

    sudo dpkg -i "$deb_file" || sudo apt-get install -f -y -q
    verify_installed "sac" "safenetauthenticationclient"
}

install_safesign() {
    log_info "=== SafeSign IC Standard ${SAFESIGN_VERSION} ==="
    local zipfile="safesign-ic-standard-linux-ub2204-${SAFESIGN_VERSION}-aet.000.zip"
    download_and_verify "$SAFESIGN_URL" "$zipfile" "$SAFESIGN_HASH"

    local safesign_dir="${TMPDIR_WORK}/safesign"
    mkdir -p "$safesign_dir"
    unzip -q "${TMPDIR_WORK}/${zipfile}" -d "$safesign_dir"

    local deb_file
    deb_file="$(find "$safesign_dir" -name "*.deb" | head -1)"
    if [[ -z "$deb_file" ]]; then
        log_error "SafeSign: arquivo .deb não encontrado dentro do zip."
        log_error "  URL usada: ${SAFESIGN_URL}"
        log_error "  Ação: verifique o conteúdo do zip ou baixe manualmente em aeteurope.com."
        INSTALL_STATUS["safesign"]="fail"
        return
    fi

    sudo dpkg -i "$deb_file" || sudo apt-get install -f -y -q
    verify_installed "safesign" "safesign"
}

install_pjeoffice() {
    log_info "=== PJeOffice Pro ${PJEOFFICE_VERSION} ==="
    local zipfile="pjeoffice-pro-${PJEOFFICE_VERSION}-linux_x64.zip"
    download_and_verify "$PJEOFFICE_URL" "$zipfile" "$PJEOFFICE_HASH"

    local pje_dir="${TMPDIR_WORK}/pjeoffice"
    mkdir -p "$pje_dir"
    unzip -q "${TMPDIR_WORK}/${zipfile}" -d "$pje_dir"

    # Detectar formato de instalação: .deb ou script install.sh
    local deb_file
    deb_file="$(find "$pje_dir" -name "*.deb" | head -1)"
    if [[ -n "$deb_file" ]]; then
        sudo dpkg -i "$deb_file" || sudo apt-get install -f -y -q
    elif [[ -f "${pje_dir}/install.sh" ]]; then
        sudo bash "${pje_dir}/install.sh"
    else
        log_error "PJeOffice: formato de instalação não reconhecido no zip."
        log_error "  Ação: instale manualmente a partir de docs.pje.jus.br/servicos-negociais/pjeoffice-pro/"
        INSTALL_STATUS["pjeoffice"]="fail"
        return
    fi
    verify_installed "pjeoffice" "pjeoffice-pro"
}

install_websigner() {
    log_info "=== Web Signer ${WEBSIGNER_VERSION} ==="
    download_and_verify \
        "$WEBSIGNER_URL" \
        "webpki-chrome-64-deb" \
        "$WEBSIGNER_HASH"
    sudo dpkg -i "${TMPDIR_WORK}/webpki-chrome-64-deb" || sudo apt-get install -f -y -q
    verify_installed "websigner" "webpki-chrome"
}

install_antigravity() {
    log_info "=== Antigravity IDE (snap preferido) ==="
    install_snap_or_deb \
        "antigravity" \
        "$ANTIGRAVITY_SNAP" \
        "$ANTIGRAVITY_URL" \
        "antigravity-linux.deb" \
        "$ANTIGRAVITY_HASH" \
        "antigravity"
}

install_office_pwa() {
    log_info "=== Microsoft 365 PWA ==="

    if ! command -v google-chrome &>/dev/null; then
        log_warn "Microsoft 365 PWA: Google Chrome não instalado — etapa ignorada."
        log_warn "  Ação: instale o Chrome primeiro e execute 'bash instalar.sh' novamente."
        INSTALL_STATUS["office_pwa"]="skipped"
        return
    fi

    # Instalar ícones
    sudo mkdir -p /usr/local/share/pje-no-linux/icons/
    if [[ -d "${SCRIPT_DIR}/assets/icons" ]] && \
       ls "${SCRIPT_DIR}/assets/icons/"*.png &>/dev/null 2>&1; then
        sudo install -Dm644 "${SCRIPT_DIR}/assets/icons/"*.png \
            /usr/local/share/pje-no-linux/icons/
    fi

    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"

    # Word
    cat > "${apps_dir}/microsoft-word.desktop" <<'EOF'
[Desktop Entry]
Name=Microsoft Word
Exec=google-chrome --app=https://www.office.com/launch/word --profile-directory=Default
Icon=/usr/local/share/pje-no-linux/icons/word-128.png
Type=Application
Categories=Office;WordProcessor;
StartupNotify=true
EOF

    # Excel
    cat > "${apps_dir}/microsoft-excel.desktop" <<'EOF'
[Desktop Entry]
Name=Microsoft Excel
Exec=google-chrome --app=https://www.office.com/launch/excel --profile-directory=Default
Icon=/usr/local/share/pje-no-linux/icons/excel-128.png
Type=Application
Categories=Office;Spreadsheet;
StartupNotify=true
EOF

    # PowerPoint
    cat > "${apps_dir}/microsoft-powerpoint.desktop" <<'EOF'
[Desktop Entry]
Name=Microsoft PowerPoint
Exec=google-chrome --app=https://www.office.com/launch/powerpoint --profile-directory=Default
Icon=/usr/local/share/pje-no-linux/icons/powerpoint-128.png
Type=Application
Categories=Office;Presentation;
StartupNotify=true
EOF

    # Outlook
    cat > "${apps_dir}/microsoft-outlook.desktop" <<'EOF'
[Desktop Entry]
Name=Microsoft Outlook
Exec=google-chrome --app=https://www.office.com/launch/outlook --profile-directory=Default
Icon=/usr/local/share/pje-no-linux/icons/outlook-128.png
Type=Application
Categories=Network;Email;
StartupNotify=true
EOF

    log_ok "Atalhos criados: Word, Excel, PowerPoint, Outlook."
    INSTALL_STATUS["office_pwa"]="ok"
}

# =============================================================================
# CONFIGURAÇÃO PÓS-INSTALAÇÃO (US1 — FR-007, FR-008, FR-009)
# =============================================================================

configure_pkcs11() {
    [[ "${INSTALL_STATUS[sac]:-fail}" != "ok" ]] && return

    log_info "Detectando biblioteca PKCS#11 do SAC..."
    local pkcs11_lib=""

    local candidate
    for candidate in \
        /usr/lib/libeToken.so \
        /usr/lib/x86_64-linux-gnu/libeToken.so \
        /usr/lib/libIDPrimePKCS11.so \
        /usr/lib/x86_64-linux-gnu/libIDPrimePKCS11.so; do
        if [[ -f "$candidate" ]]; then
            pkcs11_lib="$candidate"
            break
        fi
    done

    if [[ -z "$pkcs11_lib" ]]; then
        log_warn "PKCS#11: biblioteca do SAC não encontrada nos caminhos padrão."
        log_warn "  Ação: configure manualmente a biblioteca PKCS#11 no PJeOffice e Web Signer."
        log_warn "  Caminhos verificados: /usr/lib/libeToken.so, /usr/lib/libIDPrimePKCS11.so"
        return
    fi

    log_ok "Biblioteca PKCS#11 detectada: ${pkcs11_lib}"

    # Configurar PJeOffice Pro — campo pkcs11Library em local.json
    local pje_config="$HOME/.pjeoffice-pro/local.json"
    if [[ -f "$pje_config" ]] && command -v python3 &>/dev/null; then
        python3 - <<PYEOF
import json, sys
try:
    with open('${pje_config}') as f:
        cfg = json.load(f)
    cfg['pkcs11Library'] = '${pkcs11_lib}'
    with open('${pje_config}', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('[OK] PJeOffice: biblioteca PKCS#11 configurada em ${pje_config}')
except Exception as e:
    print(f'[AVISO] PJeOffice: não foi possível atualizar ${pje_config}: {e}', file=sys.stderr)
    print('[AVISO] Configure manualmente: edite ${pje_config} e defina pkcs11Library para ${pkcs11_lib}')
PYEOF
    elif [[ ! -f "$pje_config" ]]; then
        log_warn "PJeOffice: ${pje_config} não encontrado — execute o PJeOffice ao menos uma vez e reconfigure."
    fi
}

configure_native_messaging() {
    [[ "${INSTALL_STATUS[websigner]:-fail}" != "ok" ]] && return

    local manifest_src="/opt/softplan-websigner/manifest.json"
    if [[ ! -f "$manifest_src" ]]; then
        log_warn "Web Signer: manifest.json não encontrado em ${manifest_src}."
        log_warn "  Ação: verifique se o Web Signer foi instalado corretamente em /opt/softplan-websigner/"
        return
    fi

    # Chrome
    if command -v google-chrome &>/dev/null; then
        local chrome_nmh="/etc/opt/chrome/native-messaging-hosts"
        sudo mkdir -p "$chrome_nmh"
        sudo cp "$manifest_src" "${chrome_nmh}/br.com.softplan.webpki.json"
        log_ok "Native Messaging Host configurado para Chrome."
    fi

    # Firefox — requer allowed_extensions em vez de allowed_origins
    if $FIREFOX_PRESENT; then
        local ff_nmh="$HOME/.mozilla/native-messaging-hosts"
        mkdir -p "$ff_nmh"
        local ff_manifest="${ff_nmh}/br.com.softplan.webpki.json"
        if command -v python3 &>/dev/null; then
            python3 - <<PYEOF
import json, sys
try:
    with open('${manifest_src}') as f:
        m = json.load(f)
    m.pop('allowed_origins', None)
    m['allowed_extensions'] = ['webpki@softplan.com.br']
    with open('${ff_manifest}', 'w') as f:
        json.dump(m, f, indent=2)
    print('[OK] Native Messaging Host configurado para Firefox.')
except Exception as e:
    print(f'[AVISO] Firefox NMH: {e}', file=sys.stderr)
PYEOF
        else
            cp "$manifest_src" "$ff_manifest"
            log_ok "Native Messaging Host copiado para Firefox (verifique allowed_extensions manualmente)."
        fi
    fi
}

prompt_autostart() {
    [[ "${INSTALL_STATUS[pjeoffice]:-fail}" != "ok" ]] && return

    printf "\nDeseja adicionar o PJeOffice Pro ao autostart do GNOME? [s/N] "
    local resposta
    read -r resposta
    if [[ "${resposta,,}" == "s" ]]; then
        local autostart_dir="$HOME/.config/autostart"
        mkdir -p "$autostart_dir"
        cat > "${autostart_dir}/pjeoffice-pro.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=PJeOffice Pro
Exec=/opt/pjeoffice-pro/bin/pjeoffice-pro
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
        log_ok "PJeOffice Pro adicionado ao autostart do GNOME."
    else
        log_info "Autostart não configurado (padrão)."
    fi
}

configure_screenshot_shortcut() {
    log_info "=== Atalho Captura de Tela (Super+Shift+S) ==="

    if ! command -v gsettings &>/dev/null; then
        log_warn "gsettings não disponível — atalho não configurado automaticamente."
        INSTALL_STATUS["screenshot"]="skipped"
        return
    fi

    # Equivalente ao Win+Shift+S do Windows: captura de área selecionável
    if gsettings set org.gnome.shell.keybindings show-screenshot-ui \
        "['<Shift><Super>s']" 2>/dev/null; then
        log_ok "Super+Shift+S configurado para captura de tela de área."
        INSTALL_STATUS["screenshot"]="ok"
    else
        log_warn "Não foi possível configurar o atalho automaticamente."
        log_warn "  Manual: Configurações → Teclado → Atalhos → Capturas de tela"
        log_warn "  → 'Fazer uma captura de tela interativamente' → pressione Super+Shift+S"
        INSTALL_STATUS["screenshot"]="fail"
    fi
}

install_all() {
    install_chrome
    install_sac
    install_safesign
    install_pjeoffice
    install_websigner
    install_antigravity
    install_office_pwa
    configure_pkcs11
    configure_native_messaging
    prompt_autostart
    configure_screenshot_shortcut
}

# =============================================================================
# TELA DE CONCLUSÃO (US1 — FR-005, SC-002)
# =============================================================================

show_final_status() {
    printf "\n${BOLD}══════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}  Resumo da instalação${NC}\n"
    printf "${BOLD}══════════════════════════════════════════════════════${NC}\n\n"

    local -A labels=(
        [chrome]="Google Chrome (stable)"
        [sac]="SafeNet SAC ${SAC_VERSION}"
        [safesign]="SafeSign IC ${SAFESIGN_VERSION}"
        [pjeoffice]="PJeOffice Pro ${PJEOFFICE_VERSION}"
        [websigner]="Web Signer ${WEBSIGNER_VERSION}"
        [antigravity]="Antigravity IDE"
        [office_pwa]="Microsoft 365 PWA"
        [screenshot]="Atalho Super+Shift+S (captura de área)"
    )

    local component
    for component in chrome sac safesign pjeoffice websigner antigravity office_pwa screenshot; do
        local status="${INSTALL_STATUS[$component]:-fail}"
        local label="${labels[$component]}"
        case "$status" in
            ok)      printf "  ${GREEN}✔${NC} %s\n" "$label" ;;
            skipped) printf "  ${YELLOW}—${NC} %s (ignorado — pré-requisito ausente)\n" "$label" ;;
            fail)    printf "  ${RED}✗${NC} %s\n" "$label" ;;
        esac
    done

    printf "\n  Log completo: %s\n\n" "$LOG_FILE"

    # Exit code não-zero se qualquer componente essencial falhou
    local failed=false
    local essential_component
    for essential_component in chrome sac safesign pjeoffice websigner; do
        if [[ "${INSTALL_STATUS[$essential_component]:-fail}" == "fail" ]]; then
            failed=true
        fi
    done
    if $failed; then
        log_warn "Um ou mais componentes essenciais falharam. Verifique o log para detalhes."
        exit 1
    fi
}

# =============================================================================
# PONTO DE ENTRADA
# =============================================================================

main() {
    # Detecção e consentimento ANTES de qualquer alocação de recursos
    check_environment
    check_dependencies
    show_summary_and_confirm

    # Diretório temporário criado APÓS consentimento do usuário
    TMPDIR_WORK="$(mktemp -d)"
    chmod 700 "${TMPDIR_WORK}"

    install_all
    show_final_status
}

main "$@"
