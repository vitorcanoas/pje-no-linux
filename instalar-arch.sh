#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Instalador de Componentes (Arch Linux / Omarchy)
# Instala: Google Chrome, SafeNet SAC, PJeOffice Pro, Web Signer,
#          Shodo (Justiça do Trabalho) e Microsoft 365 PWA
#
# Uso: bash instalar-arch.sh
# Requisitos: Arch Linux ou derivado (Omarchy, EndeavourOS, Manjaro, CachyOS)
#             Arquitetura x86_64 | Bash 5.0+ | helper AUR (yay ou paru)
#
# Diferença do instalar.sh (Ubuntu/Debian): aqui os componentes proprietários
# vêm do AUR, que já os empacota. Não há download manual com SHA256 fixo —
# a verificação de integridade é feita pelo PKGBUILD de cada pacote, e a
# revisão do PKGBUILD é responsabilidade do usuário (o helper AUR mostra o
# diff antes de compilar). Ver README.md, seção "Arch/Omarchy".
# =============================================================================

# === CONFIGURAÇÃO ===
# Versão deste instalador (SemVer). Impressa no cabeçalho e gravada no log,
# para que meses depois se saiba qual versão produziu aquela instalação.
# Ao mudar versão/hash de componente proprietário, registre em CHANGELOG.md.
readonly PJE_LINUX_VERSION="1.0.0"

# Pacotes do repositório oficial (pacman)
readonly PACMAN_BASE=(pcsclite ccid opensc p11-kit)

# Pacotes do AUR — nome exato no AUR
readonly AUR_CHROME="google-chrome"
# Middleware do eToken: NÃO é fixo. 'sac-core' cobre 5110/5300/IDPrime;
# 'sac-core-legacy' cobre a linha antiga (5100/JC/PRO, ex-Aladdin). Instalar o
# errado deixa o token ilegível — o sac-core chega a remover libeTPkcs11.so e
# /etc/eToken.conf. escolher_pacote_sac() decide pelo dispositivo detectado.
readonly AUR_SAC_CORE_MODERNO="sac-core"
readonly AUR_SAC_CORE_LEGACY="sac-core-legacy"
AUR_SAC_CORE="$AUR_SAC_CORE_MODERNO"   # padrão; ajustado por escolher_pacote_sac
readonly AUR_SAC_GUI="sac-gui"
readonly AUR_PJEOFFICE="pje-office"
readonly AUR_WEBSIGNER="softplan-websigner"
readonly AUR_SHODO="shodo"

# --help ANTES do log: quem só quer ler a ajuda não deve deixar arquivo de log
# no $HOME. A ajuda completa (mostrar_ajuda) exige as variáveis de pacote já
# definidas acima; aqui só marcamos a intenção e desviamos no fim do arquivo.
PEDIU_AJUDA=false
for _arg in "$@"; do
    [[ "$_arg" == "-h" || "$_arg" == "--help" ]] && PEDIU_AJUDA=true
done
unset _arg
readonly PEDIU_AJUDA

# Log — captura toda saída (inclusive tela de consentimento)
LOG_FILE="$HOME/pje-install-arch-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_FILE
# umask ANTES do touch: sem isso o arquivo nasce 644 e existe uma janela em que
# o log — que contém o ATR do chip, identificador persistente do token — fica
# legível para todo mundo. O chmod depois só fecha a porta tarde demais.
if ! $PEDIU_AJUDA; then
    ( umask 077 && touch "$LOG_FILE" )
    chmod 600 "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

AUR_HELPER=""
FIREFOX_PRESENT=false
INSTALL_SHODO=false
declare -A INSTALL_STATUS=()

# Módulo de detecção de certificado (matriz de modelos + teste de middleware).
# Carregado por 'source' para reaproveitar detectar_certificado/relatorio_certificado
# em vez de duplicar a lógica aqui. Ele não pede PIN em nenhuma função.
DETECTAR_CERT_LIB="${SCRIPT_DIR}/lib/detectar-certificado.sh"
if [[ -r "$DETECTAR_CERT_LIB" ]]; then
    # shellcheck source=lib/detectar-certificado.sh
    source "$DETECTAR_CERT_LIB"
    DETECTAR_CERT_OK=true
else
    DETECTAR_CERT_OK=false
fi
readonly DETECTAR_CERT_LIB DETECTAR_CERT_OK

# Módulo de detecção de distribuição (guard-rail cruzado com instalar.sh).
# Compartilhado por 'source' em vez de duplicado — mesma razão do módulo acima.
DETECTAR_DISTRO_LIB="${SCRIPT_DIR}/lib/detectar-distro.sh"
if [[ -r "$DETECTAR_DISTRO_LIB" ]]; then
    # shellcheck source=lib/detectar-distro.sh
    source "$DETECTAR_DISTRO_LIB"
fi
readonly DETECTAR_DISTRO_LIB

# Pula apenas a confirmação inicial deste script (flag --yes).
# NUNCA pula a revisão do PKGBUILD do AUR: essa é do helper e é onde o
# usuário vê o que vai compilar e rodar na máquina dele.
ASSUME_YES=false

# =============================================================================
# LOG
# =============================================================================

log_ok()    { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[AVISO]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERRO]${NC} %s\n" "$*"; }
log_info()  { printf "[INFO] %s\n" "$*"; }

# Verifica instalação via pacman -Q e registra em INSTALL_STATUS
# Uso: verify_installed <id> <pacote>
verify_installed() {
    local id="$1" pkg="$2"
    if pacman -Q "$pkg" &>/dev/null; then
        INSTALL_STATUS["$id"]="ok"
        log_ok "${pkg}: instalado e verificado via pacman ($(pacman -Q "$pkg" | awk '{print $2}'))."
        return 0
    fi
    INSTALL_STATUS["$id"]="fail"
    log_error "${pkg}: não foi instalado."
    log_error "  Se você respondeu 'n' à revisão do PKGBUILD, foi só isso — nada quebrou."
    log_error "  Ação: rode ${AUR_HELPER} -S ${pkg}, leia o PKGBUILD e responda 's'."
    log_error "  Se o erro foi de compilação/download, a mensagem do ${AUR_HELPER} acima diz qual."
    return 1
}

# Instala pacote do AUR pelo helper. Idempotente: pula se já instalado.
# Uso: install_aur <id> <pacote>
install_aur() {
    local id="$1" pkg="$2"

    if pacman -Q "$pkg" &>/dev/null; then
        INSTALL_STATUS["$id"]="ok"
        log_ok "${pkg}: já instalado ($(pacman -Q "$pkg" | awk '{print $2}')) — nada a fazer."
        return 0
    fi

    log_info "${pkg}: instalando do AUR via ${AUR_HELPER}..."
    # --needed  : não reinstala o que já está atualizado
    # sem --noconfirm: o usuário DEVE ver e aprovar o PKGBUILD (é código de
    # terceiro que roda na compilação). Não automatize esta revisão.
    if "$AUR_HELPER" -S --needed "$pkg"; then
        # || true é OBRIGATÓRIO: verify_installed retorna 1 quando o pacote não
        # aparece no pacman -Q (ex.: o usuário revisou o PKGBUILD e respondeu
        # "n" — o yay sai 0 sem instalar). Sob 'set -e' esse 1 viraria o status
        # da função e abortaria o script inteiro, sem imprimir o resumo final.
        verify_installed "$id" "$pkg" || true
    else
        INSTALL_STATUS["$id"]="fail"
        log_error "${pkg}: falha na instalação pelo ${AUR_HELPER}."
        log_error "  Ação: tente manualmente — ${AUR_HELPER} -S ${pkg}"
        log_error "  Página do pacote: https://aur.archlinux.org/packages/${pkg}"
    fi
    return 0
}

# =============================================================================
# DETECÇÃO DE AMBIENTE
# =============================================================================

check_environment() {
    log_info "Verificando ambiente..."

    local arch
    arch="$(uname -m)"
    if [[ "$arch" != "x86_64" ]]; then
        log_error "Arquitetura não suportada: este script suporta apenas x86_64."
        log_error "  Detectado: ${arch}"
        log_error "  Ação: execute em uma máquina com processador Intel/AMD de 64 bits."
        exit 1
    fi

    # Guard-rail cruzado: quem rodou o script errado descobre agora, com o
    # nome da própria distro e o comando certo na tela — não com um erro
    # genérico de 'pacman: command not found' cinquenta linhas adiante.
    if declare -F detectar_distro &>/dev/null; then
        detectar_distro
        exigir_familia arch "instalar.sh"
    elif ! command -v pacman &>/dev/null; then
        log_error "'pacman' não encontrado — este script é para Arch Linux e derivados."
        log_error "  Em Ubuntu, Zorin, Mint ou Debian use: bash instalar.sh"
        exit 1
    fi

    local distro="Arch Linux"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        distro="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-$NAME}")"
    fi

    if [[ -d "$HOME/.local/share/omarchy" ]] || command -v omarchy &>/dev/null; then
        log_info "Omarchy detectado — usando Hyprland/Wayland como ambiente gráfico."
    fi

    log_ok "Ambiente: ${distro} (x86_64)"
}

check_dependencies() {
    log_info "Verificando dependências..."

    local dep
    for dep in curl unzip git base-devel-gcc; do
        case "$dep" in
            base-devel-gcc)
                # base-devel é grupo, não pacote — testa pelo compilador
                if ! command -v gcc &>/dev/null || ! command -v make &>/dev/null; then
                    log_error "Grupo 'base-devel' ausente (necessário para compilar do AUR)."
                    log_error "  Ação: sudo pacman -S --needed base-devel"
                    exit 1
                fi
                ;;
            *)
                if ! command -v "$dep" &>/dev/null; then
                    log_error "Dependência ausente: '${dep}'."
                    log_error "  Ação: sudo pacman -S --needed ${dep}"
                    exit 1
                fi
                ;;
        esac
    done

    # Helper AUR — yay e paru compartilham a sintaxe -S usada aqui
    local helper
    for helper in yay paru; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            break
        fi
    done

    if [[ -z "$AUR_HELPER" ]]; then
        log_error "Nenhum helper AUR encontrado (yay ou paru)."
        log_error "  Ação: instale o yay —"
        log_error "    sudo pacman -S --needed git base-devel"
        log_error "    git clone https://aur.archlinux.org/yay.git /tmp/yay"
        log_error "    cd /tmp/yay && makepkg -si"
        exit 1
    fi
    log_info "Helper AUR: ${AUR_HELPER}"

    if command -v firefox &>/dev/null || pacman -Q firefox &>/dev/null; then
        FIREFOX_PRESENT=true
        log_info "Firefox detectado — Native Messaging Host será configurado para Firefox."
    fi

    # Chrome via Flatpak/Snap é incompatível com Native Messaging Host
    if command -v flatpak &>/dev/null && \
       flatpak list --app 2>/dev/null | grep -qi 'com.google.Chrome'; then
        log_warn "Chrome detectado via Flatpak."
        log_warn "O Chrome Flatpak roda em sandbox e NÃO enxerga o Native Messaging Host"
        log_warn "do sistema — o Web Signer não funcionará nele."
        log_warn "  Ação: instale o Chrome do AUR (este script faz isso) e use-o para o e-SAJ."
    fi

    log_ok "Dependências verificadas."
}

# =============================================================================
# RESUMO E CONSENTIMENTO
# =============================================================================

# Este instalador é INTERATIVO: pergunta e espera resposta. Sob 'curl | bash'
# o stdin é o pipe do curl, não o teclado — toda pergunta recebe EOF na hora e
# o script morreria calado. Melhor abortar cedo, explicando o que fazer.
exigir_terminal_interativo() {
    if [[ -t 0 ]]; then
        return 0
    fi
    # Sem TTY e sem --yes: não há como obter consentimento. Sai com instrução.
    log_error "Entrada padrão não é um terminal — este instalador é interativo."
    log_error "  Ele precisa perguntar o modelo do seu token e confirmar cada etapa."
    log_error "  Provável causa: execução por 'curl ... | bash' ou dentro de outro script."
    log_error "  Ação: baixe o repositório e rode de forma interativa —"
    log_error "        git clone https://github.com/vitorcanoas/pje-no-linux.git"
    log_error "        cd pje-no-linux && bash instalar-arch.sh"
    exit 1
}

show_summary_and_confirm() {
    exigir_terminal_interativo

    local distro="Arch Linux"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        distro="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-$NAME}")"
    fi

    printf "\n${BOLD}"
    printf "╔═══════════════════════════════════════════════════════╗\n"
    printf "║   PJe no Linux — Instalador (Arch Linux / Omarchy)    ║\n"
    printf "╚═══════════════════════════════════════════════════════╝${NC}\n\n"
    printf "  Versão       : pje-no-linux %s (instalar-arch.sh)\n" "$PJE_LINUX_VERSION"
    printf "  SO detectado : %s (x86_64)\n" "$distro"
    printf "  Helper AUR   : %s\n" "$AUR_HELPER"
    printf "  Log          : %s\n\n" "$LOG_FILE"
    printf "  Do repositório oficial (pacman):\n"
    printf "    • pcsclite, ccid       — daemon e driver do leitor de smartcard\n"
    printf "    • opensc, p11-kit      — camada PKCS#11\n\n"
    printf "  Do AUR (compilados/empacotados por mantenedores da comunidade):\n"
    printf "    • %-22s — Google Chrome stable\n" "$AUR_CHROME"
    printf "    • %-22s — [PROPRIETÁRIO] SafeNet/Thales eToken\n" "sac-core(-legacy) + ${AUR_SAC_GUI}"
    printf "      %-22s   (core escolhido pelo modelo do token detectado)\n" ""
    printf "    • %-22s — PJeOffice Pro (CNJ oficial)\n" "$AUR_PJEOFFICE"
    printf "    • %-22s — [PROPRIETÁRIO] Web Signer (Softplan)\n" "$AUR_WEBSIGNER"
    printf "    • Microsoft 365 PWA (Word, Excel, PowerPoint, Outlook)\n\n"
    printf "  ${YELLOW}⚠  SafeNet SAC e Web Signer são software proprietário.${NC}\n"
    printf "     A instalação implica aceite dos termos de cada fabricante.\n\n"
    printf "  ${YELLOW}⚠  Pacotes do AUR são mantidos pela comunidade, não pelo Arch.${NC}\n"
    printf "     O ${AUR_HELPER} vai mostrar cada PKGBUILD antes de compilar.\n"
    printf "     ${BOLD}Leia-os${NC} — é código de terceiro que roda na sua máquina.\n\n"
    printf "  ${YELLOW}⚠  Será criada uma regra PERMANENTE de sistema:${NC}\n"
    printf "     /etc/polkit-1/rules.d/50-pcscd-pje.rules\n"
    printf "     Ela libera a leitura do token (pcsc-lite) para o seu grupo mesmo\n"
    printf "     em sessão não-ativa; sem ela o token \"some\" sem erro visível.\n"
    printf "     Para remover depois: bash desinstalar-arch.sh (ou apague o arquivo).\n\n"

    # --yes pula APENAS esta confirmação. O resumo acima continua sendo
    # impresso (e gravado no log) — quem usa --yes abre mão de responder,
    # não de ver. A revisão do PKGBUILD do AUR continua acontecendo.
    if $ASSUME_YES; then
        log_info "--yes informado: confirmação inicial dispensada."
        log_warn "A revisão dos PKGBUILDs do AUR continua sendo pedida pelo ${AUR_HELPER}."
        printf "\n"
        return 0
    fi

    printf "Deseja continuar? [s/N] "
    local resposta
    read -r resposta || resposta=""
    if [[ "${resposta,,}" != "s" ]]; then
        log_info "Instalação cancelada pelo usuário."
        exit 0
    fi

    printf "\nInstalar também o Shodo (assinador da Justiça do Trabalho, para TRT)? [s/N] "
    read -r resposta || resposta=""
    if [[ "${resposta,,}" == "s" ]]; then
        INSTALL_SHODO=true
    fi
    printf "\n"
}

# =============================================================================
# INSTALAÇÃO DOS COMPONENTES
# =============================================================================

install_base() {
    log_info "=== Base PKCS#11 / smartcard (repositório oficial) ==="
    if sudo pacman -S --needed --noconfirm "${PACMAN_BASE[@]}"; then
        INSTALL_STATUS["base"]="ok"
        log_ok "Base instalada: ${PACMAN_BASE[*]}"
    else
        INSTALL_STATUS["base"]="fail"
        log_error "Falha ao instalar a base pelo pacman."
        log_error "  Ação: sudo pacman -Syu && sudo pacman -S ${PACMAN_BASE[*]}"
    fi
}

enable_pcscd() {
    log_info "=== Serviço pcscd (leitor de smartcard) ==="
    # O token só é enxergado se o daemon pcscd estiver rodando. Ativamos o
    # .socket em vez do .service: systemd sobe o daemon sob demanda, quando
    # algo consulta o leitor, em vez de mantê-lo residente.
    if sudo systemctl enable --now pcscd.socket; then
        INSTALL_STATUS["pcscd"]="ok"
        log_ok "pcscd.socket habilitado e ativo (daemon sobe sob demanda)."
    else
        INSTALL_STATUS["pcscd"]="fail"
        log_error "Não foi possível habilitar o pcscd.socket."
        log_error "  Ação: sudo systemctl enable --now pcscd.socket"
    fi
}

# O pcsclite 2.5.x instala uma policy polkit com allow_inactive=no. Em sessão
# não-ativa (serviço systemd --user, SSH, PWA em janela própria) o acesso ao
# leitor é negado SEM erro claro: o token simplesmente "some". A regra abaixo
# libera as duas ações do pcsc-lite para quem está no grupo wheel.
configure_polkit_pcscd() {
    log_info "=== Regra polkit para o pcscd ==="
    local rule_file="/etc/polkit-1/rules.d/50-pcscd-pje.rules"

    if [[ -f "$rule_file" ]]; then
        log_ok "Regra polkit já existe: ${rule_file}"
        INSTALL_STATUS["polkit"]="ok"
        return 0
    fi

    # O grupo NÃO é fixo: a regra abaixo libera o pcsc-lite para um grupo, e se
    # o usuário não pertencer a ele a regra é criada, marcada ✔, e o token
    # continua sumindo — falha silenciosa exatamente igual à que se quer curar.
    local polkit_grupo="wheel"
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx wheel; then
        log_warn "Você (${USER}) NÃO está no grupo 'wheel'."
        if id -nG "$USER" | tr ' ' '\n' | grep -qx sudo; then
            polkit_grupo="sudo"
            log_info "  Grupo 'sudo' encontrado — a regra será escrita para ele."
        else
            log_warn "  A regra padrão (grupo wheel) não valeria para você."
            log_warn "  Ação: sudo usermod -aG wheel ${USER} e faça logout/login,"
            log_warn "        ou edite ${rule_file} trocando 'wheel' pelo seu grupo."
            log_warn "  Sem isso o token pode continuar sumindo em sessão não-ativa."
        fi
    fi
    log_info "Grupo usado na regra polkit: ${polkit_grupo}"

    sudo mkdir -p /etc/polkit-1/rules.d
    # Heredoc QUOTADO ('EOF'): o corpo é JavaScript com $ e aspas que não podem
    # sofrer expansão do bash.
    # Heredoc NÃO quotado apenas para interpolar ${polkit_grupo}. O corpo é
    # JavaScript: nenhum outro '$' pode aparecer sem escape.
    if sudo tee "$rule_file" >/dev/null <<EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
         action.id == "org.debian.pcsc-lite.access_card") &&
        subject.isInGroup("${polkit_grupo}")) {
        return polkit.Result.YES;
    }
});
EOF
    then
        sudo chmod 644 "$rule_file"
        sudo chown root:root "$rule_file"
        INSTALL_STATUS["polkit"]="ok"
        log_ok "Regra polkit criada: ${rule_file}"
        if sudo systemctl restart polkit; then
            log_ok "polkit reiniciado — a regra já está valendo."
        else
            log_warn "Não foi possível reiniciar o polkit."
            log_warn "  Ação: sudo systemctl restart polkit (ou reinicie a máquina)."
        fi
    else
        INSTALL_STATUS["polkit"]="fail"
        log_error "Não foi possível criar ${rule_file}."
        log_error "  Sem ela, o token pode não ser visto em sessão não-ativa."
    fi
    return 0
}

install_chrome()    { log_info "=== Google Chrome ==="; install_aur "chrome" "$AUR_CHROME"; }
install_pjeoffice() { log_info "=== PJeOffice Pro ==="; install_aur "pjeoffice" "$AUR_PJEOFFICE"; }
install_websigner() { log_info "=== Web Signer ==="; install_aur "websigner" "$AUR_WEBSIGNER"; }

# Nome do leitor reportado pelo pcscd, SEM reimplementar o parse.
#
# Preferência 1: reusar lib/detectar-certificado.sh, onde o parse POSICIONAL
# já está corrigido e testado. detectar_leitor() é seguro de chamar aqui:
# ela zera CERT_LEITORES/CERT_NUM_LEITORES na entrada e reescreve CERT_LEITOR,
# e detectar_certificado() — chamada depois em validate_token() — zera TODAS as
# CERT_* antes de rodar. Ou seja, chamar duas vezes não deixa resíduo.
#
# Preferência 2 (fallback): a lib pode não estar do lado (usuário baixou o .sh
# solto). Só nesse caso repete-se o awk POSICIONAL — cópia DELIBERADA do bloco
# de detectar_leitor(); se um dos dois mudar, o outro tem de mudar junto.
#
# O corte NUNCA pode contar campos ($1/$2/$3): a coluna 'Features' vem VAZIA na
# saída real, então $3 passa a ser a 1ª palavra do NOME. Foi assim que o
# "SafeNet" sumiu de "SafeNet eToken 5100 [Main Interface] 00 00" — e um
# "Aladdin Token JC" viraria "Token JC 00 00", deixando de casar *aladdin* e
# levando o instalador a pôr sac-core (moderno) num token antigo.
obter_nome_leitor() {
    if $DETECTAR_CERT_OK && declare -F detectar_leitor >/dev/null; then
        CERT_LEITOR=""
        detectar_leitor >/dev/null 2>&1 || true
        printf '%s' "${CERT_LEITOR:-}"
        return 0
    fi

    command -v opensc-tool &>/dev/null || return 0

    timeout 20 opensc-tool --list-readers 2>/dev/null | awk '
        /^[[:space:]]*Nr\./ { col = index($0, "Name"); next }
        /^[0-9]+[[:space:]]/ {
            if (col > 0 && length($0) >= col) {
                nome = substr($0, col)
            } else {
                nome = $0
                sub(/^[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", nome)
            }
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", nome)
            if (nome != "") { print nome; exit }
        }
    ' || true
}

# Decide entre sac-core e sac-core-legacy pelo dispositivo REALMENTE conectado.
# A decisão usa o nome do leitor reportado pelo pcscd (opensc-tool --list-readers),
# não o lsusb: um eToken 5100 aparece no lsusb como "Aladdin ... Token JC", string
# legada do vendor ID 0529, que sozinha não distingue a geração do token.
#
# POLÍTICA DO CASO DUVIDOSO: só o sac-core CAUSA DANO (remove libeTPkcs11.so e
# /etc/eToken.conf, de que a linha antiga depende). O legacy, no pior caso, é
# inútil. Logo, na dúvida NÃO se instala SAC nenhum (AUR_SAC_CORE="") — nenhum
# caminho ambíguo pode cair em sac-core por omissão.
escolher_pacote_sac() {
    local leitor="" leitor_lower

    # O modelo do token decide qual pacote instalar. Detectar vale muito mais
    # que perguntar: peça o token na porta antes de recorrer à pergunta.
    printf "\n${BOLD}Conecte o token USB AGORA${NC} e pressione Enter para eu detectar o modelo.\n"
    printf "(Se o seu certificado for A1 — arquivo .pfx/.p12, sem token — apenas pressione Enter.) "
    local _ign; read -r _ign || _ign=""
    printf "\n"

    leitor="$(obter_nome_leitor || true)"

    if [[ -z "$leitor" ]]; then
        log_warn "Nenhum leitor detectado — não dá para saber o modelo do eToken."
        log_warn "  sac-core cobre eToken 5110/5300 e IDPrime;"
        log_warn "  sac-core-legacy cobre a linha antiga (5100, JC, PRO — ex-Aladdin)."
        log_warn "  Instalar o sac-core num token antigo REMOVE libeTPkcs11.so e"
        log_warn "  /etc/eToken.conf — por isso não se escolhe às cegas."
        printf "\nO que fazer?\n"
        printf "  [1] NÃO instalar SAC agora (recomendado: conecte o token e rode de novo)\n"
        printf "  [2] Instalar a versão LEGACY (token antigo: 5100/JC/PRO)\n"
        printf "  [3] Instalar a versão MODERNA (5110/5300/IDPrime)\n"
        printf "Opção [1]: "
        local r; read -r r || r=""
        case "$r" in
            2) AUR_SAC_CORE="$AUR_SAC_CORE_LEGACY" ;;
            3) AUR_SAC_CORE="$AUR_SAC_CORE_MODERNO" ;;
            *) AUR_SAC_CORE="" ;;
        esac
        if [[ -z "$AUR_SAC_CORE" ]]; then
            log_info "Nenhum SAC será instalado nesta execução."
        else
            log_info "Pacote escolhido: ${AUR_SAC_CORE}"
        fi
        return 0
    fi

    log_info "Leitor detectado: ${leitor}"
    leitor_lower="${leitor,,}"

    case "$leitor_lower" in
        *"etoken 5110"*|*"etoken 5300"*|*idprime*)
            AUR_SAC_CORE="$AUR_SAC_CORE_MODERNO"
            log_ok "Modelo da linha atual — usando ${AUR_SAC_CORE}."
            ;;
        *"etoken 5100"*|*"etoken jc"*|*"etoken pro"*|*"token jc"*|*"token pro"*|*aladdin*)
            AUR_SAC_CORE="$AUR_SAC_CORE_LEGACY"
            log_ok "Modelo da linha antiga — usando ${AUR_SAC_CORE}."
            log_info "  (o sac-core comum não cobre este token e removeria libeTPkcs11.so)"
            ;;
        *etoken*|*safenet*)
            # Família reconhecida, geração indefinida: quem decide é o usuário.
            log_warn "eToken detectado, mas o modelo exato não ficou claro."
            printf "\nModelo detectado: %s\n" "$leitor"
            printf "É um token ANTIGO (5100 / JC / PRO, ex-Aladdin)? [S/n/pular] "
            local r; read -r r || r=""
            case "${r,,}" in
                n|nao|não) AUR_SAC_CORE="$AUR_SAC_CORE_MODERNO" ;;
                p|pular)   AUR_SAC_CORE="" ;;
                *)         AUR_SAC_CORE="$AUR_SAC_CORE_LEGACY" ;;
            esac
            if [[ -z "$AUR_SAC_CORE" ]]; then
                log_info "Nenhum SAC será instalado nesta execução."
            else
                log_info "Pacote escolhido: ${AUR_SAC_CORE}"
            fi
            ;;
        *)
            # Dispositivo fora da família eToken/SafeNet: pode ser leitora de
            # cartão de outro fabricante, ou nome que o parse não cobriu. Não é
            # motivo para instalar o pacote que causa dano.
            AUR_SAC_CORE=""
            log_warn "Dispositivo não reconhecido como eToken/SafeNet: ${leitor}"
            log_warn "  Nenhum SAC será instalado (o sac-core pode quebrar tokens antigos)."
            log_warn "  Se este é mesmo um token SafeNet, rode de novo com o token conectado"
            log_warn "  ou instale o pacote correto à mão:"
            log_warn "    ${AUR_SAC_CORE_MODERNO} (5110/5300/IDPrime) ou ${AUR_SAC_CORE_LEGACY} (5100/JC/PRO)."
            ;;
    esac
    return 0
}

install_sac() {
    log_info "=== SafeNet SAC (eToken) ==="
    escolher_pacote_sac

    # AUR_SAC_CORE vazio = caso ambíguo. Não se instala nada: o sac-core errado
    # DESTRÓI a configuração de um token da linha antiga, e ficar sem middleware
    # é reversível (basta rodar de novo com o token conectado). A sac-gui sozinha
    # não serve para nada, então também é pulada.
    if [[ -z "$AUR_SAC_CORE" ]]; then
        INSTALL_STATUS["sac"]="skipped"
        INSTALL_STATUS["sac_gui"]="skipped"
        log_warn "SAC não instalado — modelo do token indeterminado."
        log_warn "  Ação: conecte o token USB e rode este script de novo."
        return 0
    fi

    install_aur "sac" "$AUR_SAC_CORE"
    # A GUI é opcional: serve para trocar o PIN e ver o certificado. A leitura
    # do token funciona só com o sac-core.
    install_aur "sac_gui" "$AUR_SAC_GUI"
    # A GUI é dispensável, mas 'skipped' silencia falha REAL de build/download.
    # Só rebaixa quando o pacote sequer existe no AUR; se o helper falhou de
    # verdade, o status 'fail' fica, e o resumo mostra ✗ em vez de "— (ignorado)".
    if [[ "${INSTALL_STATUS[sac_gui]:-fail}" != "ok" ]]; then
        log_warn "sac-gui não instalado — o token continua funcionando pelo sac-core."
        log_warn "  A GUI só é necessária para trocar PIN / inspecionar o token."
        if ! "$AUR_HELPER" -Si "$AUR_SAC_GUI" &>/dev/null; then
            log_info "  ${AUR_SAC_GUI} não existe mais no AUR — marcando como ignorado."
            INSTALL_STATUS["sac_gui"]="skipped"
        else
            log_warn "  O pacote existe no AUR: a instalação FALHOU (não foi ignorada)."
            log_warn "  Ação: ${AUR_HELPER} -S ${AUR_SAC_GUI} e leia o erro do build."
        fi
    fi
}

install_shodo() {
    if ! $INSTALL_SHODO; then
        INSTALL_STATUS["shodo"]="skipped"
        return
    fi
    log_info "=== Shodo (Justiça do Trabalho) ==="
    install_aur "shodo" "$AUR_SHODO"
}

install_office_pwa() {
    log_info "=== Microsoft 365 PWA ==="

    if ! command -v google-chrome-stable &>/dev/null && ! command -v google-chrome &>/dev/null; then
        log_warn "Microsoft 365 PWA: Google Chrome não instalado — etapa ignorada."
        log_warn "  Ação: instale o Chrome e execute 'bash instalar-arch.sh' novamente."
        INSTALL_STATUS["office_pwa"]="skipped"
        return
    fi

    # No Arch o binário do AUR chama-se google-chrome-stable
    local chrome_bin="google-chrome-stable"
    command -v "$chrome_bin" &>/dev/null || chrome_bin="google-chrome"

    local icon_dir=/usr/local/share/pje-no-linux/icons
    sudo mkdir -p "$icon_dir"
    # 'install -D' com glob de vários arquivos trata o último como destino;
    # com '-t <dir>' o destino é explícito e o '--' encerra as opções.
    if compgen -G "${SCRIPT_DIR}/assets/icons/*.png" >/dev/null; then
        sudo install -m644 -t "$icon_dir" -- "${SCRIPT_DIR}/assets/icons/"*.png
    fi

    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"

    local app name categories icon_path
    local icons_faltando=false
    for app in word:Word:Office\;WordProcessor \
               excel:Excel:Office\;Spreadsheet \
               powerpoint:PowerPoint:Office\;Presentation \
               outlook:Outlook:Network\;Email; do
        IFS=: read -r app name categories <<<"$app"
        # O repositório não versiona os PNGs (assets/icons/ só tem .gitkeep).
        # Apontar para um arquivo inexistente deixa o atalho sem ícone nenhum;
        # o ícone do próprio Chrome é um fallback que sempre existe.
        local icon_path="${icon_dir}/${app}-128.png"
        if [[ ! -f "$icon_path" ]]; then
            icon_path="google-chrome"
            icons_faltando=true
        fi
        cat > "${apps_dir}/microsoft-${app}.desktop" <<EOF
[Desktop Entry]
Name=Microsoft ${name}
Exec=${chrome_bin} --app=https://www.office.com/launch/${app} --profile-directory=Default
Icon=${icon_path}
Type=Application
Categories=${categories};
StartupNotify=true
EOF
    done

    update-desktop-database "$apps_dir" &>/dev/null || true
    log_ok "Atalhos criados: Word, Excel, PowerPoint, Outlook."
    if $icons_faltando; then
        log_warn "Ícones próprios do Office não encontrados em ${icon_dir}."
        log_warn "  Os atalhos usam o ícone do Chrome — funcionam igual, só mudam de aparência."
    fi
    INSTALL_STATUS["office_pwa"]="ok"
}

# =============================================================================
# CONFIGURAÇÃO PÓS-INSTALAÇÃO
# =============================================================================

configure_pkcs11() {
    [[ "${INSTALL_STATUS[sac]:-fail}" != "ok" ]] && return

    log_info "Detectando biblioteca PKCS#11 do SAC..."
    local pkcs11_lib=""

    # No Arch as libs ficam em /usr/lib (não há multiarch como no Debian)
    local candidate
    for candidate in \
        /usr/lib/libeToken.so \
        /usr/lib/pkcs11/libeToken.so \
        /usr/lib/libIDPrimePKCS11.so \
        /usr/lib/pkcs11/libIDPrimePKCS11.so; do
        if [[ -f "$candidate" ]]; then
            pkcs11_lib="$candidate"
            break
        fi
    done

    # Fallback: o PKGBUILD pode ter mudado o caminho entre versões
    if [[ -z "$pkcs11_lib" && -n "$AUR_SAC_CORE" ]] && pacman -Q "$AUR_SAC_CORE" &>/dev/null; then
        # '|| true' dentro do $( ): sem match o grep sai 1, o 'pipefail'
        # propaga e a atribuição falharia sob 'set -e', matando o script
        # justamente no caminho "não encontrado" que o if abaixo trata.
        pkcs11_lib="$(pacman -Ql "$AUR_SAC_CORE" 2>/dev/null \
            | awk '{print $2}' \
            | grep -E '(libeToken|libIDPrimePKCS11)\.so$' \
            | head -1 || true)"
        [[ -n "$pkcs11_lib" ]] && \
            log_info "Biblioteca localizada via 'pacman -Ql ${AUR_SAC_CORE}'."
    fi

    if [[ -z "$pkcs11_lib" ]]; then
        log_warn "PKCS#11: biblioteca do SAC não encontrada nos caminhos padrão."
        log_warn "  Ação: localize com 'pacman -Ql ${AUR_SAC_CORE} | grep -i pkcs11'"
        log_warn "  e configure-a manualmente no PJeOffice e no Web Signer."
        return
    fi

    log_ok "Biblioteca PKCS#11 detectada: ${pkcs11_lib}"

    # Registra o módulo no p11-kit — assim opensc, Chrome e Firefox
    # enxergam o token sem configuração individual.
    local p11_module="/usr/share/p11-kit/modules/safenet.module"
    if [[ -d /usr/share/p11-kit/modules ]] && [[ ! -f "$p11_module" ]]; then
        printf 'module: %s\n' "$pkcs11_lib" | sudo tee "$p11_module" >/dev/null
        log_ok "Módulo PKCS#11 registrado no p11-kit: ${p11_module}"
    fi

    # PJeOffice Pro — campo pkcs11Library em local.json
    local pje_config="$HOME/.pjeoffice-pro/local.json"
    if [[ -f "$pje_config" ]] && command -v python3 &>/dev/null; then
        python3 - "$pje_config" "$pkcs11_lib" <<'PYEOF'
import json, sys
cfg_path, lib = sys.argv[1], sys.argv[2]
try:
    with open(cfg_path) as f:
        cfg = json.load(f)
    cfg['pkcs11Library'] = lib
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print(f'[OK] PJeOffice: biblioteca PKCS#11 configurada em {cfg_path}')
except Exception as e:
    print(f'[AVISO] PJeOffice: não foi possível atualizar {cfg_path}: {e}', file=sys.stderr)
    print(f'[AVISO] Configure manualmente: defina pkcs11Library = {lib}')
PYEOF
    elif [[ ! -f "$pje_config" ]]; then
        log_warn "PJeOffice: ${pje_config} não existe ainda."
        log_warn "  Ação: abra o PJeOffice uma vez e rode este script de novo."
    fi
}

configure_native_messaging() {
    [[ "${INSTALL_STATUS[websigner]:-fail}" != "ok" ]] && return

    # O pacote AUR normalmente já registra o host. Localizamos o manifest
    # pelo próprio pacman em vez de assumir um caminho fixo.
    local manifest_src=""
    local candidate
    for candidate in \
        /opt/softplan-websigner/manifest.json \
        /usr/lib/softplan-websigner/manifest.json \
        /usr/share/softplan-websigner/manifest.json; do
        [[ -f "$candidate" ]] && { manifest_src="$candidate"; break; }
    done

    if [[ -z "$manifest_src" ]]; then
        # '|| true': ver comentário idêntico em configure_pkcs11 — sem match o
        # grep sai 1, pipefail propaga e a atribuição mataria o script.
        manifest_src="$(pacman -Ql "$AUR_WEBSIGNER" 2>/dev/null \
            | awk '{print $2}' \
            | grep -E 'br\.com\.softplan\.webpki\.json$|manifest\.json$' \
            | head -1 || true)"
    fi

    if [[ -z "$manifest_src" || ! -f "$manifest_src" ]]; then
        log_warn "Web Signer: manifest do Native Messaging Host não localizado."
        log_warn "  Verifique com: pacman -Ql ${AUR_WEBSIGNER} | grep -i json"
        return
    fi
    log_info "Manifest do Web Signer: ${manifest_src}"

    # Chrome e Chromium leem de caminhos distintos no Arch
    local nmh_dir
    local nmh_registrado=false
    for nmh_dir in /etc/opt/chrome/native-messaging-hosts \
                   /etc/chromium/native-messaging-hosts; do
        # Só registra onde o navegador correspondente existe
        if [[ "$nmh_dir" == *chrome* ]] && \
           ! command -v google-chrome-stable &>/dev/null && \
           ! command -v google-chrome &>/dev/null; then
            continue
        fi
        if [[ "$nmh_dir" == *chromium* ]] && ! command -v chromium &>/dev/null; then
            continue
        fi
        sudo mkdir -p "$nmh_dir"
        if [[ ! -f "${nmh_dir}/br.com.softplan.webpki.json" ]]; then
            sudo cp "$manifest_src" "${nmh_dir}/br.com.softplan.webpki.json"
            log_ok "Native Messaging Host registrado em ${nmh_dir}"
        else
            log_ok "Native Messaging Host já presente em ${nmh_dir}"
        fi
        nmh_registrado=true
    done

    if [[ "$nmh_registrado" == false ]] && ! $FIREFOX_PRESENT; then
        log_error "Nenhum navegador compatível encontrado — Web Signer NÃO foi registrado."
        log_error "  Sem o Native Messaging Host o Chrome não conversa com o assinador,"
        log_error "  e o e-SAJ/PJe não vai listar nenhum certificado."
        log_error "  Ação: ${AUR_HELPER} -S ${AUR_CHROME} e rode este script de novo."
        INSTALL_STATUS["websigner"]="fail"
        return
    fi

    # Firefox — usa allowed_extensions, não allowed_origins
    if $FIREFOX_PRESENT; then
        local ff_nmh="$HOME/.mozilla/native-messaging-hosts"
        mkdir -p "$ff_nmh"
        if command -v python3 &>/dev/null; then
            python3 - "$manifest_src" "${ff_nmh}/br.com.softplan.webpki.json" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    with open(src) as f:
        m = json.load(f)
    m.pop('allowed_origins', None)
    m['allowed_extensions'] = ['webpki@softplan.com.br']
    with open(dst, 'w') as f:
        json.dump(m, f, indent=2)
    print('[OK] Native Messaging Host configurado para Firefox.')
except Exception as e:
    print(f'[AVISO] Firefox NMH: {e}', file=sys.stderr)
PYEOF
        else
            cp "$manifest_src" "${ff_nmh}/br.com.softplan.webpki.json"
            log_warn "Firefox: manifest copiado sem ajuste — confira allowed_extensions."
        fi
    fi
}

prompt_autostart() {
    [[ "${INSTALL_STATUS[pjeoffice]:-fail}" != "ok" ]] && return

    printf "\nIniciar o PJeOffice Pro automaticamente ao ligar o computador? [s/N] "
    local resposta
    read -r resposta || resposta=""
    if [[ "${resposta,,}" != "s" ]]; then
        log_info "Autostart não configurado (padrão)."
        return
    fi

    # Localiza o executável instalado pelo pacote em vez de assumir o caminho
    local pje_exec
    pje_exec="$(command -v pjeoffice-pro 2>/dev/null || true)"
    [[ -z "$pje_exec" && -x /opt/pjeoffice-pro/pjeoffice-pro.sh ]] && \
        pje_exec="/opt/pjeoffice-pro/pjeoffice-pro.sh"

    if [[ -z "$pje_exec" ]]; then
        log_warn "PJeOffice: executável não localizado — autostart não configurado."
        return
    fi

    # Hyprland (Omarchy) lê ~/.config/autostart via XDG autostart, igual ao GNOME
    local autostart_dir="$HOME/.config/autostart"
    mkdir -p "$autostart_dir"
    cat > "${autostart_dir}/pjeoffice-pro.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PJeOffice Pro
Exec=${pje_exec}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    log_ok "PJeOffice Pro adicionado ao autostart (${pje_exec})."

    if [[ -d "$HOME/.local/share/omarchy" ]] || command -v omarchy &>/dev/null; then
        log_info "Omarchy: se o autostart XDG não disparar, a forma idiomática é"
        log_info "adicionar ao ~/.config/hypr/autostart.lua:"
        log_info "  o.launch_on_start(\"${pje_exec}\")"
    fi
}

# =============================================================================
# VALIDAÇÃO DO TOKEN
# =============================================================================

# IMPORTANTE: esta validação NÃO pede e NÃO usa o PIN do certificado.
# Ela apenas enumera o leitor e lê objetos públicos do token. O PIN destrava
# a mesma sessão PKCS#11 que assina documentos — por isso ele nunca deve ser
# passado a um script. Ver README.md, seção "Segurança do certificado".
validate_token() {
    log_info "=== Validação do token (somente leitura, sem PIN) ==="

    # O lsusb aqui é só informativo. Quem decide é o pcscd, via
    # detectar_certificado: uma leitora de smartcard com cartão inserido pode
    # não casar nenhuma destas strings, e nem por isso o certificado é ilegível.
    local usb_info
    usb_info="$(lsusb 2>/dev/null \
        | grep -iE 'aladdin|safenet|gemalto|thales|token|smart' \
        | head -1 || true)"
    if [[ -n "$usb_info" ]]; then
        log_ok "Dispositivo USB detectado: ${usb_info}"
    else
        log_info "Nenhum token USB óbvio no lsusb — seguindo pela detecção do pcscd."
    fi

    if ! command -v pkcs11-tool &>/dev/null; then
        log_warn "pkcs11-tool ausente (pacote opensc) — validação ignorada."
        INSTALL_STATUS["token"]="skipped"
        return 0
    fi

    # A detecção real fica em lib/detectar-certificado.sh. NÃO voltar a decidir
    # por 'grep -qiE "slot [0-9]"' aqui: esse padrão casa com a saída de um token
    # ILEGÍVEL — o slot é listado junto de "(token not recognized)" e ZERO
    # certificados, e o script daria "✔ token legível" para um advogado que
    # concluiria que pode peticionar. O módulo exige "token label" e rejeita
    # explicitamente "token not recognized".
    if ! $DETECTAR_CERT_OK; then
        log_warn "lib/detectar-certificado.sh não encontrado — validação ignorada."
        log_warn "  Esperado em: ${DETECTAR_CERT_LIB}"
        INSTALL_STATUS["token"]="skipped"
        return 0
    fi

    log_info "Detectando certificado e middleware PKCS#11..."
    detectar_certificado || true
    relatorio_certificado

    case "$CERT_STATUS" in
        ok)
            INSTALL_STATUS["token"]="ok"
            log_ok "Token legível pela camada PKCS#11 (middleware: ${CERT_MIDDLEWARE})."
            log_info "Para ver o certificado (também sem PIN):"
            if [[ "$CERT_MIDDLEWARE" == "opensc" ]]; then
                log_info "  pkcs11-tool --list-objects --type cert"
            else
                log_info "  pkcs11-tool --module ${CERT_MIDDLEWARE} --list-objects --type cert"
            fi
            ;;
        sem_middleware)
            INSTALL_STATUS["token"]="fail"
            log_error "Token conectado, mas NENHUM middleware instalado consegue lê-lo."
            log_error "  Dispositivo: ${CERT_LEITOR:-<desconhecido>}"
            # CERT_PACOTE pode ser o sentinela "[MANUAL]" (modelo conhecido, mas
            # SEM pacote no AUR que o cubra). Mandar 'yay -S [MANUAL]' é comando
            # inválido na cara do usuário — pior que não sugerir nada.
            if [[ -n "$CERT_PACOTE" && "$CERT_PACOTE" != "$MATRIZ_SEM_ROTA" ]]; then
                log_error "  Ação 1: instale o pacote correto — ${AUR_HELPER} -S ${CERT_PACOTE}"
            elif [[ "$CERT_PACOTE" == "$MATRIZ_SEM_ROTA" ]]; then
                log_error "  Ação 1: este modelo NÃO tem pacote pronto no AUR."
                log_error "          Baixe o middleware no site do fabricante do seu"
                log_error "          certificado (ou da certificadora que o emitiu) e"
                log_error "          instale-o manualmente. Modelo: ${CERT_MODELO:-<indefinido>}"
            fi
            log_error "  Ação 2: confira se o pacote do eToken é o da geração certa"
            log_error "          (sac-core = 5110/5300/IDPrime; sac-core-legacy = 5100/JC/PRO)"
            log_error "  Ação 3: desconecte e reconecte o token, e rode este script de novo"
            ;;
        sem_cartao)
            INSTALL_STATUS["token"]="skipped"
            log_warn "Leitora presente, mas sem cartão inserido."
            log_warn "  Ação: insira o cartão (ou conecte o token) e rode o script de novo."
            ;;
        *)
            INSTALL_STATUS["token"]="skipped"
            log_warn "Nenhum leitor/token detectado pelo pcscd."
            log_warn "  Ação 1: sudo systemctl enable --now pcscd.socket"
            log_warn "  Ação 2: conecte o token e rode 'bash lib/detectar-certificado.sh'"
            ;;
    esac
    return 0
}

install_all() {
    install_base
    enable_pcscd
    configure_polkit_pcscd
    install_chrome
    install_sac
    install_pjeoffice
    install_websigner
    install_shodo
    install_office_pwa
    configure_pkcs11
    configure_native_messaging
    prompt_autostart
    validate_token
}

# =============================================================================
# TELA DE CONCLUSÃO
# =============================================================================

show_final_status() {
    printf "\n${BOLD}══════════════════════════════════════════════════════${NC}\n"
    printf "${BOLD}  Resumo da instalação${NC}\n"
    printf "${BOLD}══════════════════════════════════════════════════════${NC}\n\n"

    local -A labels=(
        [base]="Base PKCS#11 (pcsclite, ccid, opensc, p11-kit)"
        [pcscd]="Serviço pcscd.socket"
        [polkit]="Regra polkit do pcscd (sessão não-ativa)"
        [chrome]="Google Chrome"
        [sac]="SafeNet SAC (core)"
        [sac_gui]="SafeNet SAC (GUI, opcional)"
        [pjeoffice]="PJeOffice Pro"
        [websigner]="Web Signer"
        [shodo]="Shodo (Justiça do Trabalho, opcional)"
        [office_pwa]="Microsoft 365 PWA"
        [token]="Leitura do token (sem PIN)"
    )

    local component
    for component in base pcscd polkit chrome sac sac_gui pjeoffice websigner shodo office_pwa token; do
        local status="${INSTALL_STATUS[$component]:-fail}"
        local label="${labels[$component]}"
        case "$status" in
            ok)      printf "  ${GREEN}✔${NC} %s\n" "$label" ;;
            skipped) printf "  ${YELLOW}—${NC} %s (ignorado)\n" "$label" ;;
            fail)    printf "  ${RED}✗${NC} %s\n" "$label" ;;
        esac
    done

    printf "\n  Log completo: %s\n" "$LOG_FILE"

    printf "\n${BOLD}Próximos passos manuais:${NC}\n"
    printf "  1. Instale a extensão Web Signer no Chrome:\n"
    printf "     https://chromewebstore.google.com/detail/web-signer/bbafmabaelnnkondpfpjmdklbmfnbmol\n"
    printf "  2. Conecte o token e acesse o e-SAJ ou o PJe/TRT pelo Chrome.\n"
    printf "  3. O PIN é digitado por você, na janela do assinador — nunca em script.\n\n"

    local failed=false
    local essential
    for essential in base pcscd chrome sac pjeoffice websigner; do
        if [[ "${INSTALL_STATUS[$essential]:-fail}" == "fail" ]]; then
            failed=true
        fi
    done
    if $failed; then
        log_warn "Um ou mais componentes essenciais falharam. Verifique o log."
        exit 1
    fi
}

# =============================================================================
# PONTO DE ENTRADA
# =============================================================================

SUDO_KEEPALIVE_PID=""

# Compilar do AUR leva minutos. Sem isto o sudo expira no meio e o script fica
# parado pedindo senha numa tela cheia de log de compilação — o usuário não vê.
# Pedimos a senha UMA vez, logo após o consentimento, e renovamos em background.
start_sudo_keepalive() {
    log_info "As próximas etapas precisam de sudo. Digite sua senha uma única vez."
    if ! sudo -v; then
        log_error "Não foi possível obter privilégios de administrador (sudo)."
        exit 1
    fi
    while true; do
        sudo -n true 2>/dev/null || exit
        sleep 50
        kill -0 "$$" 2>/dev/null || exit
    done &
    SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    return 0
}

mostrar_ajuda() {
    cat <<AJUDA
PJe no Linux — instalador para Arch Linux e derivados (versão ${PJE_LINUX_VERSION})

USO
    bash instalar-arch.sh [opções]

O QUE ELE FAZ
    Deixa o processo eletrônico (PJe, e-SAJ, Projudi) funcionando no Arch:
    instala o middleware do token, o PJeOffice Pro, o Web Signer e o Chrome,
    e configura o Native Messaging Host e a regra polkit do leitor de cartão.

O QUE ELE INSTALA
    Repositório oficial (pacman)
        pcsclite, ccid          daemon e driver do leitor de smartcard
        opensc, p11-kit         camada PKCS#11
    AUR (empacotado pela comunidade; você revisa cada PKGBUILD)
        ${AUR_CHROME}
        sac-core ou sac-core-legacy, ${AUR_SAC_GUI}   [PROPRIETÁRIO] SafeNet/Thales
        ${AUR_PJEOFFICE}                              PJeOffice Pro (CNJ)
        ${AUR_WEBSIGNER}                              [PROPRIETÁRIO] Softplan
        ${AUR_SHODO}                                  opcional (Justiça do Trabalho)
    Também cria /etc/polkit-1/rules.d/50-pcscd-pje.rules (regra permanente).

OPÇÕES
    -y, --yes     Pula a confirmação inicial deste script.
                  NÃO pula a revisão dos PKGBUILDs do AUR — essa é do helper
                  (yay/paru) e continua sendo mostrada. Ainda exige terminal.
    -h, --help    Mostra esta ajuda e sai, sem instalar nada.

DESINSTALAR
    bash desinstalar-arch.sh

PIN DO CERTIFICADO
    Nenhum script deste repositório pede, lê, grava ou registra o seu PIN.

LOG
    ~/pje-install-arch-AAAAMMDD-HHMMSS.log (permissão 600; inclui a versão
    do instalador que rodou).

Mudanças entre versões: CHANGELOG.md · Guia completo: docs/arch/README.md
AJUDA
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)  mostrar_ajuda; exit 0 ;;
            -y|--yes)   ASSUME_YES=true; shift ;;
            *)
                log_error "Opção desconhecida: $1"
                log_error "  Ação: bash instalar-arch.sh --help"
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    trap stop_sudo_keepalive EXIT
    log_info "pje-no-linux versão ${PJE_LINUX_VERSION} — instalar-arch.sh"
    check_environment
    check_dependencies
    show_summary_and_confirm
    start_sudo_keepalive
    install_all
    show_final_status
}

main "$@"
