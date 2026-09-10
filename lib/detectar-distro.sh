#!/usr/bin/env bash
# =============================================================================
# lib/detectar-distro.sh — identifica a família da distribuição.
# Carregado por 'source' pelos instaladores e desinstaladores.
#
# Define (globais, readonly após detectar_distro):
#   DISTRO_ID      id cru do /etc/os-release   (ex.: omarchy, zorin, ubuntu)
#   DISTRO_NOME    nome legível                (ex.: "Omarchy 4")
#   DISTRO_FAMILIA debian | arch | desconhecida
#   PKG_MANAGER    apt | pacman | ""
#
# Este arquivo NÃO lê, pede, grava ou registra o PIN do certificado —
# ele só olha /etc/os-release e a presença dos gerenciadores de pacote.
#
# Nota de implementação: '. /etc/os-release' roda em SUBSHELL, para não
# vazar as ~20 variáveis do arquivo (NAME, VERSION, HOME_URL...) para o
# script que deu source aqui. E não usamos 'lsb_release': é pacote
# separado, ausente por padrão no Arch e em contêineres Debian mínimos.
# =============================================================================

# shellcheck disable=SC2034  # variáveis são consumidas por quem dá source neste arquivo
detectar_distro() {
    DISTRO_ID=""; DISTRO_NOME=""; DISTRO_FAMILIA="desconhecida"; PKG_MANAGER=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        DISTRO_ID="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
        # shellcheck disable=SC1091
        DISTRO_NOME="$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-${NAME:-}}")"
        local id_like
        # shellcheck disable=SC1091
        id_like="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}")"

        case " ${DISTRO_ID} ${id_like} " in
            *" arch "*|*" archlinux "*|*" omarchy "*) DISTRO_FAMILIA="arch"   ;;
            *" debian "*|*" ubuntu "*)                DISTRO_FAMILIA="debian" ;;
        esac
    fi

    # Rede de segurança: derivada que não declara ID_LIKE (acontece).
    # O gerenciador de pacotes presente é a prova material.
    if [[ "$DISTRO_FAMILIA" == "desconhecida" ]]; then
        if   command -v pacman  &>/dev/null; then DISTRO_FAMILIA="arch"
        elif command -v apt-get &>/dev/null; then DISTRO_FAMILIA="debian"
        fi
    fi

    case "$DISTRO_FAMILIA" in
        arch)   PKG_MANAGER="pacman" ;;
        debian) PKG_MANAGER="apt"    ;;
    esac

    [[ -n "$DISTRO_NOME" ]] || DISTRO_NOME="${DISTRO_ID:-desconhecida}"
    return 0
}

# Guard-rail cruzado: chamado no topo do script, com a família que ELE atende.
# Quem rodar o script errado descobre em 1 segundo, com o comando certo na tela.
exigir_familia() {
    local esperada="$1" script_certo="$2"
    [[ "${DISTRO_FAMILIA:-desconhecida}" == "$esperada" ]] && return 0

    printf '\n\033[0;31m[ERRO]\033[0m Script errado para esta distribuição.\n\n' >&2
    printf '  Sua distribuição  : %s\n'   "${DISTRO_NOME:-desconhecida}"    >&2
    printf '  Família detectada : %s\n'   "${DISTRO_FAMILIA:-desconhecida}" >&2
    printf '  Este script é para: %s\n\n' "$esperada"                       >&2

    if [[ "${DISTRO_FAMILIA:-desconhecida}" == "desconhecida" ]]; then
        printf '  Não foi possível identificar sua distribuição.\n' >&2
        printf '  Rode "cat /etc/os-release" e abra uma issue com a saída:\n' >&2
        printf '  https://github.com/vitorcanoas/pje-no-linux/issues\n\n' >&2
    else
        printf '  Rode este comando em vez do que você usou:\n\n' >&2
        printf '      bash %s\n\n' "$script_certo" >&2
    fi
    exit 1
}
