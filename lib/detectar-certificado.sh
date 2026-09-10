#!/usr/bin/env bash
# =============================================================================
# detectar-certificado.sh — detecção de token/smartcard e middleware PKCS#11
#
# Descobre QUAL certificado A3 está conectado e QUAL biblioteca PKCS#11 sabe
# lê-lo, cobrindo os modelos usados no Brasil (não só um fabricante).
#
# Pode ser usado de duas formas:
#   • carregado pelo instalar-arch.sh  (source)
#   • executado direto para diagnóstico: bash lib/detectar-certificado.sh
#
# NENHUMA função aqui pede, lê, grava ou usa o PIN do certificado.
# Tudo é enumeração de objeto público. Ver README.md, "Segurança do certificado".
# =============================================================================

# Evita redefinir se já veio do instalador
if ! declare -F log_info &>/dev/null; then
    readonly _DC_RED='\033[0;31m'
    readonly _DC_GREEN='\033[0;32m'
    readonly _DC_YELLOW='\033[1;33m'
    readonly _DC_NC='\033[0m'
    log_ok()    { printf "${_DC_GREEN}[OK]${_DC_NC} %s\n" "$*"; }
    log_warn()  { printf "${_DC_YELLOW}[AVISO]${_DC_NC} %s\n" "$*"; }
    log_error() { printf "${_DC_RED}[ERRO]${_DC_NC} %s\n" "$*"; }
    log_info()  { printf "[INFO] %s\n" "$*"; }
fi

# =============================================================================
# MATRIZ DE MODELOS
# =============================================================================
# Formato: "padrão|middleware|pacote AUR|observação"
#
# O 'padrão' é casado (case-insensitive) contra o NOME DO LEITOR reportado pelo
# pcscd, não contra o USB ID. Motivo medido: um eToken 5100 se identifica no
# lsusb como "Aladdin Knowledge Systems Token JC" (string legada do vendor ID
# 0529), o que levaria ao middleware errado. O pcscd reporta o dispositivo real.
#
# 'opensc' como middleware = coberto pelo pacote livre, sem software
# proprietário. É sempre a primeira escolha quando funciona.
# ATENÇÃO — sac-core NÃO cobre a linha antiga do eToken.
# O PKGBUILD do 'sac-core' declara textualmente que serve para 5110/5300/IDPrime
# e que "for the old Alladin eToken you should use sac-core-legacy"; ele inclusive
# REMOVE libeTPkcs11.so e /etc/eToken.conf. O 'sac-core-legacy' (10.0.37-6) é que
# instala libeToken.so.10.0.37 e o driver aks-ifdh.bundle em /usr/lib/pcsc/drivers/.
# Por isso 5100/JC/PRO apontam para sac-core-legacy, e 5110/5300/IDPrime para sac-core.
# SENTINELA "sem rota automática": usado nos campos 'middleware' e 'pacote'
# quando o modelo É conhecido mas NÃO existe pacote no AUR que o cubra.
# O relatório mostra a orientação manual em vez de mandar instalar um pacote
# inexistente — pacote inventado é pior que lacuna assumida, porque falha só
# na hora da instalação, na frente do usuário.
# Guarda de reentrância: sob 'set -e', redeclarar um 'readonly' aborta o script
# inteiro. Sem isto, um segundo 'source' deste módulo (dois callers, ou um
# caller que recarrega) mata o processo sem mensagem.
if [[ -z "${MATRIZ_SEM_ROTA:-}" ]]; then
readonly MATRIZ_SEM_ROTA="[MANUAL]"

readonly -a MATRIZ_TOKENS=(
    # --- SafeNet / Thales (linha ATUAL 5110/5300 → sac-core) ---
    # [SPEC] O OpenSC tem issues ABERTAS para o 5110/5300 (erro "invalid pin
    # padding", OpenSC#3488 e discussão #2793). Por isso, aqui o proprietário
    # vem antes do opensc — é o inverso da regra geral do resto da matriz.
    # [LIVE] PKGBUILD do sac-core instala libeToken.so e libIDPrimePKCS11.so
    # direto em /usr/lib (e REMOVE o nome legado libeTPkcs11.so).
    "etoken 5110|/usr/lib/libeToken.so|sac-core|SafeNet eToken 5110 (linha atual)"
    "etoken 5300|/usr/lib/libeToken.so|sac-core|SafeNet eToken 5300 (formato nano)"

    # --- SafeNet / Aladdin (linha ANTIGA → sac-core-legacy) ---
    # [LIVE] O PKGBUILD do sac-core-legacy NÃO instala em /usr/lib: instala em
    # /usr/lib/sac-10.0/libeToken.so.10.0.37 com symlinks no mesmo diretório
    # (é lá que ele acha o libcrypto.so do OpenSSL 1.0 de que depende).
    # Apontar para /usr/lib/libeToken.so aqui seria caminho que nunca existe.
    "etoken 5100|/usr/lib/sac-10.0/libeToken.so|sac-core-legacy|SafeNet eToken 5100 (linha antiga Aladdin)"
    "etoken jc|/usr/lib/sac-10.0/libeToken.so|sac-core-legacy|Aladdin eToken JC (linha antiga)"
    "etoken pro|/usr/lib/sac-10.0/libeToken.so|sac-core-legacy|Aladdin eToken PRO (linha antiga)"
    "aladdin|/usr/lib/sac-10.0/libeToken.so|sac-core-legacy|Aladdin (linha antiga do eToken)"

    # --- Gemalto/Thales IDPrime (smartcard) ---
    # [SPEC] O opensc cobre o IDPrime 940 desde 0.25.0 (bug de enumeração de
    # certificados corrigido pelo PR OpenSC#2958); o Arch extra está em 0.27.1.
    # Como esta entrada só é consultada DEPOIS de o opensc puro ter falhado
    # (ETAPA 1 da orquestração), o fallback correto é o proprietário sac-core.
    "idprime|/usr/lib/libIDPrimePKCS11.so|sac-core|Gemalto/Thales IDPrime MD 830/930/940"

    # --- Genéricos SafeNet: só casam se nenhum padrão específico acima casou ---
    "etoken|/usr/lib/libeToken.so|sac-core|SafeNet eToken (família, modelo indefinido)"
    "safenet|/usr/lib/libeToken.so|sac-core|SafeNet (genérico)"

    # --- GD Burti / Giesecke+Devrient — SafeSign IC, NÃO o SAC ---
    # [SPEC] "GD Burti" é Giesecke & Devrient (não Gemalto — o revendedor
    # brasileiro erra o nome). O middleware é o SafeSign Identity Client da
    # A.E.T. Europe, confirmado por manual da Valid Certificadora (SafeSign IC
    # 3.5.2) e por tutorial de instalação em Fedora.
    # [LIVE] Extraí o .deb oficial da fonte do PKGBUILD safesignidentityclient
    # 4.5.0.0 e listei o conteúdo: o módulo PKCS#11 é
    # /usr/lib/libaetpkss.so (symlink) → libaetpkss.so.3.9.33.1.
    # [SPEC] O G+D/StarSign NÃO tem página na wiki do OpenSC — tentar opensc
    # aqui só perde tempo; vai direto ao proprietário.
    "burti|/usr/lib/libaetpkss.so|safesignidentityclient|GD Burti / Giesecke+Devrient (SafeSign IC)"
    "starsign|/usr/lib/libaetpkss.so|safesignidentityclient|G+D StarSign (SafeSign IC)"
    "sm@rtcafe|/usr/lib/libaetpkss.so|safesignidentityclient|G+D Sm@rtCafé (SafeSign IC)"
    "giesecke|/usr/lib/libaetpkss.so|safesignidentityclient|Giesecke+Devrient (SafeSign IC)"
    "safesign|/usr/lib/libaetpkss.so|safesignidentityclient|SafeSign Identity Client"

    # --- Watchdata (ProxKey / W-Key) — SEM ROTA AUTOMÁTICA ---
    # [LIVE] Consultei o AUR RPC v5: watchdata-pkcs11, wdpkcs e proxkey NÃO
    # existem. Não há PKGBUILD para o middleware da Watchdata em nenhum nome.
    # [SPEC] Também não há entrada de Watchdata/ProxKey na wiki do OpenSC.
    # Nenhuma das duas rotas está garantida — por isso o pacote é o sentinela
    # [MANUAL]: o relatório orienta o usuário em vez de tentar instalar um
    # pacote inexistente (pacote inventado falha na cara do advogado).
    # [INFER, fonte fraca] O caminho do módulo proprietário é citado como
    # /usr/lib/WatchData/ProxKey/lib/libwdpkcs_SignatureP11.so por fonte
    # terciária indiana — não confirmado no Brasil nem no Arch, por isso NÃO
    # vira caminho de middleware aqui.
    "watchdata|[MANUAL]|[MANUAL]|Watchdata ProxKey / W-Key — sem pacote no AUR"
    "proxkey|[MANUAL]|[MANUAL]|ProxKey (Watchdata) — sem pacote no AUR"
    "w-key|[MANUAL]|[MANUAL]|W-Key (Watchdata) — sem pacote no AUR"

    # --- Feitian — opensc PRIMEIRO, fallback proprietário ---
    # [SPEC] A wiki do OpenSC tem página dedicada ao ePass2003 e afirma que a
    # própria Feitian contribui o driver livre ("epass2003") ao projeto.
    # Estas entradas só são lidas depois de o opensc puro já ter falhado, então
    # apontam para o fallback: [LIVE] epass2003-sdk-linux (AUR, EnterSafe
    # Castle SDK) instala /usr/lib/libcastle.so.1.0.0 + symlink libcastle.so.
    "epass2003|/usr/lib/libcastle.so|epass2003-sdk-linux|Feitian ePass2003 (opensc primeiro; este é o fallback)"
    "epass3003|/usr/lib/libcastle.so|epass2003-sdk-linux|Feitian ePass3003 (opensc primeiro; este é o fallback)"
    "epass|/usr/lib/libcastle.so|epass2003-sdk-linux|Feitian ePass (opensc primeiro; este é o fallback)"
    "feitian|/usr/lib/libcastle.so|epass2003-sdk-linux|Feitian (opensc primeiro; este é o fallback)"
    "entersafe|/usr/lib/libcastle.so|epass2003-sdk-linux|EnterSafe/Feitian (fallback Castle SDK)"

    # --- Athena — opensc nativo, sem proprietário ---
    # [SPEC] Wiki do OpenSC tem página própria (Athena-ASEPCOS-ASEKey); o
    # driver ASEPCOS é nativo. Não existe pacote proprietário no AUR e não
    # inventamos um: se o opensc falhou, a força bruta é a rota seguinte.
    "asekey|opensc|opensc|Athena ASEKey (driver ASEPCOS nativo do opensc)"
    "asedrive|opensc|opensc|Athena ASEDrive III/IIIe (opensc nativo)"
    "athena|opensc|opensc|Athena (opensc nativo, driver ASEPCOS)"

    # --- Oberthur / Idemia — opensc nativo; Bit4ID como fallback ---
    # [SPEC] Wiki do OpenSC tem página do applet Oberthur AuthentIC v2.2.
    # [LIVE] libbit4opki 1.3.3.2-1 existe no AUR ("Bit4ID Oberthur Middleware"),
    # mas o PKGBUILD só extrai um .deb opaco — o caminho do .so NÃO está
    # declarado em lugar nenhum que eu tenha medido [N/D]. Por isso o pacote é
    # citado, mas o campo de middleware fica em opensc: a força bruta e a
    # varredura do sistema acham o .so depois de instalado, sem que eu precise
    # afirmar um caminho que não medi.
    "authentic|opensc|libbit4opki|Oberthur AuthentIC v2.2 (opensc nativo; libbit4opki se variante Bit4ID)"
    "oberthur|opensc|libbit4opki|Oberthur (opensc nativo; libbit4opki se variante Bit4ID)"
    "cosmo|opensc|libbit4opki|Oberthur ID-One Cosmo (opensc nativo)"
    "idemia|opensc|libbit4opki|Idemia (sucessora da Oberthur/Morpho)"

    # --- Morpho / Safran — o pacote é da LEITORA, não do token ---
    # [LIVE] ccid-morpho 1:1.4.3-2 existe, mas o PKGBUILD instala um bundle
    # ifd-ccid em /usr/lib/pcsc/drivers/ — é driver de LEITORA (PC/SC), NÃO um
    # módulo PKCS#11. Não pode entrar como caminho de middleware, senão o
    # script tenta carregá-lo no pkcs11-tool e falha.
    # [N/D] Nenhuma AC brasileira citando Morpho como mídia de e-CPF/OAB.
    "morpho|opensc|ccid-morpho|Morpho/Safran YpsID — ccid-morpho é driver da leitora, não PKCS#11"
    "safran|opensc|ccid-morpho|Safran/Morpho — ccid-morpho é driver da leitora"

    # --- Gemalto Classic / GemPC (middleware clássico) ---
    # [LIVE] libclassicclient 7.5.0_b02.00-3 existe; o PKGBUILD registra o
    # módulo no p11-kit como "libgclib.so".
    "classic client|/usr/lib/libgclib.so|libclassicclient|Gemalto Classic Client"
    "gemalto|/usr/lib/libgclib.so|libclassicclient|Gemalto (Classic Client como fallback)"

    # --- Leitoras de cartão (smartcard, não token USB) ---
    # O driver da leitora é o ccid (repo oficial). O que decide o middleware
    # é o CARTÃO inserido, não a leitora — por isso caem em opensc para teste.
    # Ficam por ÚLTIMO de propósito: são padrões amplos ("acs ", "gempc") que
    # casariam antes de entradas específicas se viessem no topo.
    "acr38|opensc|opensc|Leitora ACS ACR38 — middleware depende do cartão"
    "acr39|opensc|opensc|Leitora ACS ACR39 — middleware depende do cartão"
    "acs |opensc|opensc|Leitora ACS — middleware depende do cartão"
    "gempc|opensc|opensc|Leitora Gemalto GemPC — depende do cartão"
    "scr3310|opensc|opensc|Leitora SCM SCR3310 — depende do cartão"
    # [LIVE] scmccid 5.0.35-6 existe no AUR (Identive/SCM); é driver de leitora.
    "scm microsystems|opensc|scmccid|Leitora SCM/Identive — scmccid é driver da leitora"
)

# Módulos PKCS#11 a testar por força bruta quando a matriz não casa.
# Ordem: livre primeiro, proprietário depois.
#
# Todo caminho aqui foi medido no PKGBUILD ou no pacote de origem — não há
# caminho suposto nesta lista. Um caminho inventado não quebra nada (o laço
# testa [[ -f ]] antes), mas dá falsa sensação de cobertura ao próximo leitor.
readonly -a MODULOS_CANDIDATOS=(
    # opensc (repo oficial Arch, extra) — livre, sempre primeiro
    "/usr/lib/opensc-pkcs11.so"
    "/usr/lib/pkcs11/opensc-pkcs11.so"

    # [LIVE] sac-core: PKGBUILD instala em /usr/lib e cria os symlinks
    # em /usr/lib/pkcs11 (vêm prontos no .deb Standard).
    "/usr/lib/libeToken.so"
    "/usr/lib/pkcs11/libeToken.so"
    "/usr/lib/libIDPrimePKCS11.so"
    "/usr/lib/pkcs11/libIDPrimePKCS11.so"

    # [LIVE] sac-core-legacy: instala SOMENTE em /usr/lib/sac-10.0/ (precisa
    # do libcrypto.so do OpenSSL 1.0 que ele coloca no mesmo diretório).
    "/usr/lib/sac-10.0/libeToken.so"

    # [LIVE] safesignidentityclient: listei o .deb 4.5.0.0 da fonte do
    # PKGBUILD — libaetpkss.so é o módulo PKCS#11 (GD Burti / G+D).
    "/usr/lib/libaetpkss.so"

    # [LIVE] epass2003-sdk-linux: install -Dm755 redist/libcastle.so.1.0.0
    # em /usr/lib/, com symlink libcastle.so (Feitian ePass).
    "/usr/lib/libcastle.so"
    "/usr/lib/libcastle.so.1.0.0"

    # [LIVE] libclassicclient: registra "libgclib.so" no p11-kit (Gemalto).
    "/usr/lib/libgclib.so"

    # Removidos por serem invenção minha, sem fonte:
    #   /usr/lib/libwdpkcs.so, /usr/lib/watchdata/lib/libwdpkcs.so
    #     → não existe pacote Watchdata no AUR; o único caminho citado na
    #       literatura é /usr/lib/WatchData/ProxKey/lib/libwdpkcs_SignatureP11.so
    #       (fonte terciária indiana, [INFER] fraco). A varredura ampla do
    #       forca_bruta_modulos acha esse .so sozinho se o usuário instalar o
    #       middleware do fabricante à mão — não preciso afirmar o caminho.
    #   /usr/lib/libcmP11.so → nenhuma fonte; não achei pacote que o instale.
)
fi  # fim da guarda de reentrância (MATRIZ_SEM_ROTA)

# Preenchidos por detectar_certificado()
CERT_LEITOR=""       # nome do leitor conforme o pcscd
CERT_ATR=""          # ATR do chip
CERT_MIDDLEWARE=""   # caminho do .so que funciona (ou "opensc")
CERT_PACOTE=""       # pacote a instalar, se faltar
CERT_MODELO=""       # descrição legível
CERT_STATUS=""       # ok | sem_leitor | sem_cartao | sem_middleware
CERT_LEITORES=""     # todos os leitores vistos, um por linha ("Nome [com/sem cartão]")
CERT_NUM_LEITORES=0  # quantos leitores o pcscd enxergou

# Módulos PKCS#11 que NÃO são de smartcard e precisam ser pulados na força bruta.
# Motivo medido: /usr/lib/pkcs11/gnome-keyring-pkcs11.so publica slots VIRTUAIS
# ("SSH Keys", "Secret Store", "Gnome2 Key Storage") que trazem 'token label',
# 'serial num' e 'token manufacturer' preenchidos — ou seja, passam em qualquer
# heurística ingênua e fazem o script concluir, ERRADO, que o token A3 foi
# reconhecido. p11-kit-trust.so expõe a store de CAs do sistema e
# p11-kit-client.so é apenas um proxy para outros módulos: nenhum dos dois fala
# com o chip. Nada aqui tem relação com PIN — a exclusão é só de escopo.
MODULOS_EXCLUIDOS_REGEX='(gnome-keyring|keyring|p11-kit-client|p11-kit-trust|trust)'

# Um módulo é "de smartcard"? Decidido pelo NOME do arquivo, antes de executá-lo.
modulo_e_de_smartcard() {
    local base
    base="$(basename "$1")"
    [[ "${base,,}" =~ $MODULOS_EXCLUIDOS_REGEX ]] && return 1
    return 0
}

# =============================================================================
# ETAPA 1 — o daemon está de pé?
# =============================================================================
# Causa nº1 de "meu token não funciona no Arch": pcscd.socket desabilitado.
# Sem ele, o sistema responde "No smart card readers found" com o token
# fisicamente conectado — e o usuário conclui que o token quebrou.
verificar_pcscd() {
    if systemctl is-active --quiet pcscd.socket || systemctl is-active --quiet pcscd; then
        return 0
    fi
    log_warn "pcscd não está ativo — nenhum leitor será detectado."
    log_warn "  Ação: sudo systemctl enable --now pcscd.socket"
    return 1
}

# =============================================================================
# ETAPA 2 — que dispositivo está conectado?
# =============================================================================
detectar_leitor() {
    if ! command -v opensc-tool &>/dev/null; then
        log_error "opensc-tool ausente — instale o pacote 'opensc'."
        return 1
    fi

    local saida
    saida="$(timeout 20 opensc-tool --list-readers 2>/dev/null || true)"

    # -------------------------------------------------------------------------
    # Parse da tabela de leitores.
    #
    # A saída tem colunas de largura fixa:
    #     Nr.  Card  Features  Name
    #     0    Yes             SafeNet eToken 5100 [Main Interface] 00 00
    #
    # NÃO se pode contar campos ($1/$2/$3): a coluna 'Features' costuma vir
    # VAZIA, e aí $3 passa a ser a 1ª palavra do NOME — foi assim que o
    # "SafeNet" sumiu de "SafeNet eToken 5100 [...]" (bug medido nesta máquina).
    #
    # O corte correto é POSICIONAL: acha-se a coluna onde começa "Name" no
    # cabeçalho e pega-se substr() dali em diante. Isso é imune a coluna vazia
    # e preserva os espaços internos do nome; só as bordas são aparadas.
    #
    # Itera-se sobre TODOS os leitores: com duas leitoras, a primeira pode estar
    # sem cartão e a segunda ter o token real (cenário comum: leitora de cartão
    # vazia + token USB plugado). Só se NENHUM tiver cartão é que se reporta
    # 'sem_cartao'.
    # -------------------------------------------------------------------------
    local tabela
    tabela="$(printf '%s\n' "$saida" | awk '
        # Cabeçalho: memoriza onde a coluna "Name" começa.
        /^[[:space:]]*Nr\./ {
            col = index($0, "Name")
            next
        }
        # Linha de leitor: começa com o índice numérico.
        /^[0-9]+[[:space:]]/ {
            card = $2
            if (col > 0 && length($0) >= col) {
                nome = substr($0, col)
            } else {
                # Fallback: sem cabeçalho reconhecível (ou linha mais curta que
                # a coluna). Descarta apenas Nr. e Card, que são as duas únicas
                # colunas garantidamente não-vazias, e mantém o resto.
                nome = $0
                sub(/^[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", nome)
            }
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", nome)
            if (nome != "")
                printf "%s\t%s\n", card, nome
        }
    ')"

    if [[ -z "$tabela" ]]; then
        CERT_STATUS="sem_leitor"
        CERT_NUM_LEITORES=0
        return 1
    fi

    # Monta o inventário e escolhe o primeiro leitor COM cartão.
    local card nome primeiro_com_cartao="" primeiro_qualquer=""
    CERT_LEITORES=""
    CERT_NUM_LEITORES=0
    while IFS=$'\t' read -r card nome; do
        [[ -n "$nome" ]] || continue
        CERT_NUM_LEITORES=$((CERT_NUM_LEITORES + 1))
        [[ -n "$primeiro_qualquer" ]] || primeiro_qualquer="$nome"
        if [[ "${card,,}" == "yes" ]]; then
            CERT_LEITORES+="${nome} [com cartão]"$'\n'
            [[ -n "$primeiro_com_cartao" ]] || primeiro_com_cartao="$nome"
        else
            CERT_LEITORES+="${nome} [sem cartão]"$'\n'
        fi
    done <<<"$tabela"

    if [[ -z "$primeiro_com_cartao" ]]; then
        # Há leitor(es), mas nenhum com cartão inserido.
        CERT_LEITOR="$primeiro_qualquer"
        CERT_STATUS="sem_cartao"
        return 1
    fi

    CERT_LEITOR="$primeiro_com_cartao"

    CERT_ATR="$(timeout 20 opensc-tool --atr 2>/dev/null \
        | grep -oE '([0-9a-f]{2}:){4,}[0-9a-f]{2}' | head -1)"
    return 0
}

# =============================================================================
# ETAPA 3 — testar um módulo PKCS#11 contra o token conectado
# =============================================================================
# Usa --list-slots, que enumera slots e NÃO pede PIN.
# "token not recognized" = o módulo enxerga o leitor mas não sabe ler o chip.
#
# Não basta existir a string "token label" em algum lugar da saída: o
# gnome-keyring publica slots virtuais com 'token label' preenchido e faria o
# script mentir "reconheceu o token". A validação é semântica, em duas camadas:
#
#   (a) o módulo tem de ser de smartcard (ver MODULOS_EXCLUIDOS_REGEX);
#   (b) o SLOT reconhecido tem de ser o slot do leitor de hardware detectado.
#
# O critério de (b) é o mais robusto que se conseguiu validar na máquina: um
# módulo PKCS#11 de verdade nomeia o slot com o nome do leitor do pcscd. Medido:
#     Slot 0 (0x0): SafeNet eToken 5100 [Main Interface] 00 00
# ao passo que os slots do gnome-keyring se chamam "SSH Keys", "Secret Store",
# etc. — nenhum casa com $CERT_LEITOR. Por isso a checagem é: a linha "Slot ..."
# referencia o leitor detectado E esse slot traz 'token label' (isto é, o chip
# foi lido), e não "(token not recognized)".
#
# Se $CERT_LEITOR estiver vazio (chamada fora do fluxo normal), cai-se num
# critério conservador: exige 'token label' fora de um módulo excluído.
modulo_reconhece_token() {
    local modulo="$1"
    [[ -f "$modulo" ]] || return 1

    # (a) Camada 1 — módulo notoriamente não-smartcard.
    modulo_e_de_smartcard "$modulo" || return 1

    local saida
    saida="$(timeout 25 pkcs11-tool --module "$modulo" --list-slots 2>&1 || true)"

    slots_reconhecem_leitor "$saida"
}

# Recebe a saída de --list-slots e devolve 0 só se algum slot de HARDWARE
# referente ao leitor detectado trouxer um token lido.
slots_reconhecem_leitor() {
    local saida="$1"

    # Sem leitor conhecido: critério conservador (o módulo já passou pelo filtro
    # de nome, então 'token label' sem "not recognized" é o melhor disponível).
    if [[ -z "$CERT_LEITOR" ]]; then
        printf '%s\n' "$saida" | grep -qi 'token not recognized' && return 1
        printf '%s\n' "$saida" | grep -qiE 'token label|token info' && return 0
        return 1
    fi

    # Palavra significativa do nome do leitor: a mais longa com >=4 caracteres
    # alfanuméricos (ex.: "SafeNet", "eToken", "ProxKey"). Serve para casar
    # mesmo quando o módulo formata o nome do slot de forma um pouco diferente.
    local palavra_chave
    palavra_chave="$(printf '%s\n' "$CERT_LEITOR" \
        | tr -cs '[:alnum:]' '\n' \
        | awk 'length($0) >= 4 { if (length($0) > length(m)) m = $0 } END { print m }')"

    printf '%s\n' "$saida" | awk -v leitor="${CERT_LEITOR,,}" \
                                 -v chave="${palavra_chave,,}" '
        function low(s) { return tolower(s) }
        # Início de um slot: fecha a avaliação do slot anterior.
        /^[[:space:]]*Slot[[:space:]]+[0-9]/ {
            if (no_slot_do_leitor && tem_token) { achou = 1 }
            linha = low($0)
            no_slot_do_leitor = (index(linha, leitor) > 0) ||
                                (chave != "" && index(linha, chave) > 0)
            tem_token = 0
            next
        }
        no_slot_do_leitor && /[Tt]oken not recognized/ { tem_token = 0; no_slot_do_leitor = 0; next }
        no_slot_do_leitor && /[Tt]oken (label|info)/   { tem_token = 1 }
        END {
            if (no_slot_do_leitor && tem_token) achou = 1
            exit (achou ? 0 : 1)
        }
    '
}

# Testa o opensc puro (sem --module, usa o padrão compilado)
opensc_reconhece_token() {
    local saida
    saida="$(timeout 25 pkcs11-tool --list-slots 2>&1 || true)"
    # Mesma validação semântica: o slot com token tem de ser o do leitor real.
    slots_reconhecem_leitor "$saida"
}

# =============================================================================
# ETAPA 4 — consultar a matriz pelo nome do leitor
# =============================================================================
consultar_matriz() {
    local leitor_lower="${CERT_LEITOR,,}"
    local entrada padrao middleware pacote obs

    for entrada in "${MATRIZ_TOKENS[@]}"; do
        IFS='|' read -r padrao middleware pacote obs <<<"$entrada"
        if [[ "$leitor_lower" == *"$padrao"* ]]; then
            CERT_MIDDLEWARE="$middleware"
            CERT_PACOTE="$pacote"
            CERT_MODELO="$obs"
            return 0
        fi
    done
    return 1
}

# =============================================================================
# ETAPA 5 — força bruta: testar todo módulo instalado na máquina
# =============================================================================
# Quando a matriz não casa (modelo novo, fabricante não mapeado), tenta cada
# módulo PKCS#11 presente. É como um modelo desconhecido acaba funcionando
# sem precisar de atualização do script.
forca_bruta_modulos() {
    log_info "Modelo não mapeado — testando cada módulo PKCS#11 instalado..."

    local modulo
    for modulo in "${MODULOS_CANDIDATOS[@]}"; do
        [[ -f "$modulo" ]] || continue
        log_info "  testando ${modulo}..."
        if modulo_reconhece_token "$modulo"; then
            CERT_MIDDLEWARE="$modulo"
            CERT_MODELO="detectado por teste direto"
            log_ok "  ${modulo} reconheceu o token."
            return 0
        fi
    done

    # Varredura ampla: qualquer .so de PKCS#11 que exista no sistema
    local encontrado
    while IFS= read -r encontrado; do
        [[ -f "$encontrado" ]] || continue
        # Já testado acima?
        printf '%s\n' "${MODULOS_CANDIDATOS[@]}" | grep -qxF "$encontrado" && continue
        # Módulo que não é de smartcard (gnome-keyring, p11-kit-trust...):
        # a varredura por '*pkcs11*.so' pesca todos eles.
        if ! modulo_e_de_smartcard "$encontrado"; then
            log_info "  pulando ${encontrado} (não é módulo de smartcard)"
            continue
        fi
        log_info "  testando ${encontrado}..."
        if modulo_reconhece_token "$encontrado"; then
            CERT_MIDDLEWARE="$encontrado"
            CERT_MODELO="detectado por varredura do sistema"
            log_ok "  ${encontrado} reconheceu o token."
            return 0
        fi
    done < <(find /usr/lib /usr/lib64 /opt -maxdepth 3 \
                  \( -name '*pkcs11*.so' -o -name 'libeToken.so' -o -name 'libaetpkss.so' \) \
                  2>/dev/null | head -20)

    return 1
}

# =============================================================================
# ORQUESTRAÇÃO
# =============================================================================
detectar_certificado() {
    # Zera TUDO: sem isto, numa segunda chamada o inventário de leitores da
    # chamada anterior sobrevive e o relatório mostra leitor que já saiu.
    CERT_LEITOR=""; CERT_ATR=""; CERT_MIDDLEWARE=""
    CERT_PACOTE=""; CERT_MODELO=""; CERT_STATUS=""
    CERT_LEITORES=""; CERT_NUM_LEITORES=0

    verificar_pcscd || { CERT_STATUS="sem_leitor"; return 1; }

    if ! detectar_leitor; then
        case "$CERT_STATUS" in
            sem_cartao)
                log_warn "${CERT_NUM_LEITORES} leitor(es) detectado(s), nenhum com cartão inserido:"
                printf '%s' "$CERT_LEITORES" | while IFS= read -r _l; do
                    [[ -n "$_l" ]] && log_warn "    - ${_l}"
                done
                log_warn "  Ação: insira o cartão (ou conecte o token) e rode de novo."
                ;;
            *)
                log_warn "Nenhum leitor de smartcard detectado."
                log_warn "  Ação: conecte o token USB, ou verifique 'systemctl status pcscd.socket'."
                log_warn ""
                log_warn "  ${BOLD:-}Seu certificado é A1 (arquivo .pfx ou .p12)?${NC:-}"
                log_warn "  Então NÃO há token para conectar — e este diagnóstico não se aplica."
                log_warn "  O A1 é um arquivo: você o importa direto no PJeOffice Pro"
                log_warn "  (ou no navegador), sem leitor, sem pcscd e sem middleware."
                log_warn "  Só o A3 (token USB ou cartão) usa o que este script verifica."
                log_warn "  Veja a seção \"A1 x A3\" no README.md."
                ;;
        esac
        return 1
    fi

    log_ok "Dispositivo: ${CERT_LEITOR}"
    if (( CERT_NUM_LEITORES > 1 )); then
        log_info "Outros leitores presentes (${CERT_NUM_LEITORES} no total):"
        printf '%s' "$CERT_LEITORES" | while IFS= read -r _l; do
            [[ -n "$_l" ]] && log_info "    - ${_l}"
        done
    fi
    [[ -n "$CERT_ATR" ]] && log_info "ATR do chip: ${CERT_ATR}"

    # 1) O opensc puro já resolve? É livre — sempre a primeira escolha.
    if opensc_reconhece_token; then
        CERT_MIDDLEWARE="opensc"
        CERT_PACOTE="opensc"
        CERT_MODELO="lido nativamente pelo OpenSC (sem software proprietário)"
        CERT_STATUS="ok"
        log_ok "Token reconhecido pelo OpenSC — nenhum middleware proprietário necessário."
        return 0
    fi
    log_info "OpenSC não reconhece este chip — procurando middleware específico..."

    # 2) A matriz conhece este modelo?
    if consultar_matriz; then
        log_ok "Modelo identificado: ${CERT_MODELO}"

        if [[ "$CERT_MIDDLEWARE" == "$MATRIZ_SEM_ROTA" ]]; then
            # Sentinela: a matriz sabe qual é o modelo e sabe que NÃO existe
            # pacote no AUR para ele. Não há o que instalar automaticamente.
            # Ainda assim seguimos para a força bruta: se o usuário já instalou
            # o middleware do fabricante à mão, a varredura do sistema o acha.
            log_warn "Modelo sem rota automática de instalação neste script."
            log_warn "  Não existe pacote no AUR para este middleware."
            log_warn "  Tentando mesmo assim os módulos já presentes na máquina."
        elif [[ "$CERT_MIDDLEWARE" == "opensc" ]]; then
            # A matriz apostava no opensc, mas o passo 1 já falhou.
            log_warn "A matriz indica OpenSC para este modelo, mas ele não reconheceu o chip."
            log_warn "  Pode ser variante nova do cartão — tentando outros módulos."
        elif [[ -f "$CERT_MIDDLEWARE" ]] && modulo_reconhece_token "$CERT_MIDDLEWARE"; then
            CERT_STATUS="ok"
            log_ok "Middleware confirmado: ${CERT_MIDDLEWARE}"
            return 0
        elif [[ ! -f "$CERT_MIDDLEWARE" ]]; then
            CERT_STATUS="sem_middleware"
            log_warn "Middleware necessário ainda não instalado: ${CERT_MIDDLEWARE}"
            log_warn "  Pacote: ${CERT_PACOTE}"
            return 1
        fi
    fi

    # 3) Força bruta
    if forca_bruta_modulos; then
        CERT_STATUS="ok"
        return 0
    fi

    CERT_STATUS="sem_middleware"
    log_warn "Nenhum módulo PKCS#11 instalado reconheceu este token."
    return 1
}

# Relatório legível — usado no diagnóstico e no fim da instalação
relatorio_certificado() {
    printf "\n"
    printf "  Dispositivo  : %s\n" "${CERT_LEITOR:-<nenhum detectado>}"
    [[ -n "$CERT_ATR" ]] && printf "  ATR do chip  : %s\n" "$CERT_ATR"
    case "$CERT_STATUS" in
        ok)
            printf "  Modelo       : %s\n" "$CERT_MODELO"
            printf "  Middleware   : %s\n" "$CERT_MIDDLEWARE"
            printf "  Situação     : token legível ✔\n"
            ;;
        sem_middleware)
            printf "  Situação     : token presente, mas sem driver que o leia\n"
            [[ -n "$CERT_MODELO" ]] && printf "  Modelo       : %s\n" "$CERT_MODELO"
            if [[ "$CERT_PACOTE" == "$MATRIZ_SEM_ROTA" ]]; then
                # Sem rota automática: orientar, nunca mandar instalar pacote
                # que não existe.
                printf "  Instale      : não há pacote no AUR para este modelo\n"
                printf "\n"
                printf "  Este modelo exige o middleware do próprio fabricante,\n"
                printf "  distribuído só como .deb/.rpm — não há PKGBUILD pronto\n"
                printf "  para o Arch. Dois caminhos, nesta ordem:\n"
                printf "\n"
                printf "    1) Force o OpenSC, que às vezes lê o chip mesmo sem\n"
                printf "       estar documentado:\n"
                printf "         pkcs11-tool --module /usr/lib/opensc-pkcs11.so --list-token-slots\n"
                printf "       (só enumera o token; não pede nem usa PIN)\n"
                printf "\n"
                printf "    2) Se falhar, baixe o middleware Linux no site do\n"
                printf "       fabricante ou da sua Autoridade Certificadora e\n"
                printf "       extraia o pacote à mão:\n"
                printf "         bsdtar -xf <pacote>.deb   # ou .rpm\n"
                printf "       Depois rode este diagnóstico de novo: a varredura\n"
                printf "       do sistema acha o módulo sozinho.\n"
            elif [[ -n "$CERT_PACOTE" ]]; then
                printf "  Instale      : %s\n" "$CERT_PACOTE"
            fi
            ;;
        sem_cartao)  printf "  Situação     : leitora sem cartão inserido\n" ;;
        *)           printf "  Situação     : nenhum leitor/token detectado\n" ;;
    esac
    printf "\n"
}

# Execução direta = modo diagnóstico
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "\nDiagnóstico de certificado digital — PJe no Linux\n"
    printf "(nenhum PIN é solicitado ou usado)\n\n"
    detectar_certificado || true
    relatorio_certificado
    if [[ "$CERT_STATUS" == "ok" ]]; then
        printf "Para ver o certificado (também sem PIN):\n"
        if [[ "$CERT_MIDDLEWARE" == "opensc" ]]; then
            printf "  pkcs11-tool --list-objects --type cert\n\n"
        else
            printf "  pkcs11-tool --module %s --list-objects --type cert\n\n" "$CERT_MIDDLEWARE"
        fi
    fi
fi
