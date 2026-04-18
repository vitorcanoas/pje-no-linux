#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PJe no Linux — Atualizador de Hashes SHA256
# Baixa cada binário e exibe os hashes para colar em instalar.sh
# Uso: bash atualizar-hashes.sh
# =============================================================================

readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Versões — manter em sincronia com instalar.sh
readonly SAC_VERSION="10.8.1050"
readonly SAFESIGN_VERSION="4.6.0.0"
readonly PJEOFFICE_VERSION="v2.5.16u"
readonly WEBSIGNER_VERSION="2.12.1"

readonly SAC_URL="https://www.globalsign.com/en/safenet-drivers/USB/10.8/GlobalSign-SAC-Ubuntu-2204.zip"
readonly SAFESIGN_URL="https://safesign.gdamericadosul.com.br/content/SafeSign%20IC%20Standard%20Linux%20ub2204%20${SAFESIGN_VERSION}-AET.000.zip"
readonly PJEOFFICE_URL="https://pje-office.pje.jus.br/pro/pjeoffice-pro-${PJEOFFICE_VERSION}-linux_x64.zip"
readonly WEBSIGNER_URL="https://websigner.softplan.com.br/Downloads/${WEBSIGNER_VERSION}/webpki-chrome-64-deb"
readonly ANTIGRAVITY_URL="https://antigravity.google/download/linux"

TMPDIR_WORK=""
cleanup() { [[ -n "${TMPDIR_WORK}" ]] && rm -rf "${TMPDIR_WORK}"; }
trap cleanup EXIT

printf "${BOLD}PJe no Linux — Calculador de Hashes SHA256${NC}\n"
printf "Baixa cada binário e exibe o hash para colar em instalar.sh\n"
printf "${YELLOW}Chrome não aparece aqui: verificação GPG é feita pelo apt.${NC}\n\n"

TMPDIR_WORK="$(mktemp -d)"
chmod 700 "${TMPDIR_WORK}"

calcular() {
    local nome="$1" url="$2" arquivo="$3"
    printf "Baixando %s..." "$nome"
    if wget --timeout=60 --tries=2 -q -O "${TMPDIR_WORK}/${arquivo}" "$url"; then
        local hash
        hash="$(sha256sum "${TMPDIR_WORK}/${arquivo}" | cut -d' ' -f1)"
        printf "\r${GREEN}✔${NC} %-20s %s\n" "$nome" "$hash"
        echo "$hash"
    else
        printf "\r${YELLOW}✗${NC} %-20s falha no download — verifique a URL\n" "$nome"
        echo "PLACEHOLDER_calcular_sha256sum"
    fi
}

printf "%-22s %s\n" "Componente" "SHA256"
printf "%-22s %s\n" "----------" "------"

SAC_HASH="$(calcular      "SAC ${SAC_VERSION}"           "$SAC_URL"          "GlobalSign-SAC-Ubuntu-2204.zip")"
SAFESIGN_HASH="$(calcular "SafeSign ${SAFESIGN_VERSION}" "$SAFESIGN_URL"     "safesign.zip")"
PJEOFFICE_HASH="$(calcular "PJeOffice ${PJEOFFICE_VERSION}" "$PJEOFFICE_URL" "pjeoffice.zip")"
WEBSIGNER_HASH="$(calcular "WebSigner ${WEBSIGNER_VERSION}" "$WEBSIGNER_URL" "websigner.deb")"
ANTIGRAVITY_HASH="$(calcular "Antigravity"               "$ANTIGRAVITY_URL"  "antigravity.deb")"

printf "\n${BOLD}Cole os valores abaixo em instalar.sh:${NC}\n\n"
printf "readonly SAC_HASH=\"%s\"\n"         "$SAC_HASH"
printf "readonly SAFESIGN_HASH=\"%s\"\n"    "$SAFESIGN_HASH"
printf "readonly PJEOFFICE_HASH=\"%s\"\n"   "$PJEOFFICE_HASH"
printf "readonly WEBSIGNER_HASH=\"%s\"\n"   "$WEBSIGNER_HASH"
printf "readonly ANTIGRAVITY_HASH=\"%s\"\n" "$ANTIGRAVITY_HASH"

printf "\n${YELLOW}Lembre de commitar instalar.sh após atualizar os hashes.${NC}\n"
