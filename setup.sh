#!/usr/bin/env bash
#
# setup.sh — interactive installer for this docker-compose repo
#
# Walks you through which stacks to deploy, sets up ONE shared base
# config/data location, and generates each selected stack's .env from
# that shared base plus whatever is specific to that stack (secrets,
# ports, etc). Existing .env files are backed up, never silently lost.
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Pretty output helpers
# ---------------------------------------------------------------------------
BOLD="$(tput bold 2>/dev/null || true)"
DIM="$(tput dim 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
YELLOW="$(tput setaf 3 2>/dev/null || true)"
CYAN="$(tput setaf 6 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

header()  { echo -e "\n${BOLD}${CYAN}== $* ==${RESET}"; }
info()    { echo -e "${DIM}  $*${RESET}"; }
ok()      { echo -e "${GREEN}  ✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}  ! $*${RESET}"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_ENV="$REPO_ROOT/.env"

# ---------------------------------------------------------------------------
# Prompt helpers
# ---------------------------------------------------------------------------

# ask "Question" "default" VARNAME
ask() {
    local prompt="$1" default="$2" varname="$3" input
    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${BOLD}$prompt${RESET} [${DIM}$default${RESET}]: ")" input
    else
        read -rp "$(echo -e "${BOLD}$prompt${RESET}: ")" input
    fi
    printf -v "$varname" '%s' "${input:-$default}"
}

# ask_required "Question" VARNAME   -- keeps asking until non-empty
ask_required() {
    local prompt="$1" varname="$2" input
    while true; do
        read -rp "$(echo -e "${BOLD}$prompt${RESET} (required): ")" input
        if [[ -n "$input" ]]; then
            printf -v "$varname" '%s' "$input"
            break
        fi
        warn "This value is required."
    done
}

# ask_secret "Question" VARNAME [byte-length, default 24]
# Leave blank to auto-generate a random value.
ask_secret() {
    local prompt="$1" varname="$2" length="${3:-24}" input
    read -rp "$(echo -e "${BOLD}$prompt${RESET} ${DIM}(blank = auto-generate)${RESET}: ")" input
    if [[ -z "$input" ]]; then
        if command -v openssl >/dev/null 2>&1; then
            input="$(openssl rand -base64 "$length" | tr -dc 'A-Za-z0-9' | head -c "$length")"
            info "generated: $input"
        else
            warn "openssl not found — leaving this blank, fill it in manually later."
            input=""
        fi
    fi
    printf -v "$varname" '%s' "$input"
}

# confirm "Question" [default: y|n]  -> returns 0 for yes
confirm() {
    local prompt="$1" default="${2:-y}" input yn
    [[ "$default" == "y" ]] && yn="Y/n" || yn="y/N"
    read -rp "$(echo -e "${BOLD}$prompt${RESET} [$yn]: ")" input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy] ]]
}

# write_env "path/to/.env" "KEY=value" "KEY2=value2" ...
# Backs up an existing file before overwriting.
write_env() {
    local target="$1"; shift
    local dir; dir="$(dirname "$target")"
    mkdir -p "$dir"
    if [[ -f "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$target" "$backup"
        info "backed up existing $(basename "$target") -> $(basename "$backup")"
    fi
    printf '%s\n' "$@" > "$target"
    ok "wrote $target"
}

# ---------------------------------------------------------------------------
# Stack registry — name -> relative path in this repo
# ---------------------------------------------------------------------------
STACK_ORDER=(media dashdot forgejo immich vaultwarden invidious syncyomi tailscale caddy newt watchtower)

declare -A STACK_PATHS=(
    [media]="media"
    [dashdot]="apps/dashdot"
    [forgejo]="apps/forgejo"
    [immich]="apps/immich"
    [vaultwarden]="apps/vaultwarden"
    [invidious]="apps/invidious"
    [syncyomi]="services/syncyomi"
    [tailscale]="services/tailscale"
    [caddy]="server/caddy"
    [newt]="server/newt"
    [watchtower]="server/watchtower"
)

declare -A STACK_DESC=(
    [media]="Jellyfin + Sonarr/Radarr/Prowlarr/Bazarr/qBittorrent behind a VPN"
    [dashdot]="dash. — simple host resource dashboard"
    [forgejo]="Self-hosted Git service (Forgejo + MySQL)"
    [immich]="Immich — self-hosted photo/video backup"
    [vaultwarden]="Vaultwarden — self-hosted Bitwarden-compatible password manager"
    [invidious]="Invidious — privacy-focused YouTube frontend"
    [syncyomi]="Syncyomi — sync backend for Tachiyomi-family apps"
    [tailscale]="Tailscale node — join this host to your tailnet"
    [caddy]="Caddy — reverse proxy / automatic HTTPS (host networking)"
    [newt]="Newt — Pangolin tunnel client for remote access"
    [watchtower]="Watchtower — auto-updates other containers' images"
)

SELECTED=()

# ---------------------------------------------------------------------------
# Step 1: choose which stacks to install
# ---------------------------------------------------------------------------
choose_stacks() {
    header "Choose what to install"
    local i=1
    for name in "${STACK_ORDER[@]}"; do
        printf "  %2d) %-12s %s\n" "$i" "$name" "${STACK_DESC[$name]}"
        ((i++))
    done
    echo
    info "Enter numbers separated by spaces (e.g. '1 3 8'), or 'all'."
    local choice
    read -rp "$(echo -e "${BOLD}Your selection${RESET}: ")" choice

    if [[ "$choice" == "all" ]]; then
        SELECTED=("${STACK_ORDER[@]}")
    else
        for num in $choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#STACK_ORDER[@]} )); then
                SELECTED+=("${STACK_ORDER[$((num-1))]}")
            else
                warn "Ignoring invalid selection: $num"
            fi
        done
    fi

    if [[ ${#SELECTED[@]} -eq 0 ]]; then
        warn "Nothing selected. Exiting."
        exit 0
    fi

    echo
    ok "Will configure: ${SELECTED[*]}"
}

# ---------------------------------------------------------------------------
# Step 2: shared base paths every stack draws from
# ---------------------------------------------------------------------------
setup_base() {
    header "Shared base locations"
    info "One config root and one data root, shared by every stack you install."
    info "Each stack gets its own subfolder underneath so nothing collides."
    echo

    ask "Base config directory (persistent app configs/state)" "$HOME/docker/config" BASE_CONFIG
    ask "Base data directory (media, downloads, libraries)" "$HOME/docker/data" BASE_DATA
    ask "Extra storage volume root (leave blank if you don't have one)" "" BASE_HDD1
    local detected_tz
    detected_tz="$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")"
    ask "Timezone" "$detected_tz" BASE_TZ
    ask "Shared group id (PGID) most containers should run as" "13000" BASE_PGID
    ask "Umask" "002" BASE_UMASK

    mkdir -p "$BASE_CONFIG" "$BASE_DATA"
    ok "created $BASE_CONFIG"
    ok "created $BASE_DATA"
    if [[ -n "$BASE_HDD1" ]]; then
        mkdir -p "$BASE_HDD1"
        ok "created $BASE_HDD1"
    fi

    write_env "$BASE_ENV" \
        "# Shared base settings — generated by setup.sh on $(date)" \
        "# Every stack's own .env derives its paths from these." \
        "BASE_CONFIG=$BASE_CONFIG" \
        "BASE_DATA=$BASE_DATA" \
        "BASE_HDD1=$BASE_HDD1" \
        "BASE_TZ=$BASE_TZ" \
        "BASE_PGID=$BASE_PGID" \
        "BASE_UMASK=$BASE_UMASK"
}

# ---------------------------------------------------------------------------
# Per-stack setup functions
# ---------------------------------------------------------------------------

setup_media() {
    header "media (Jellyfin + *arr stack)"
    local config_root="$BASE_CONFIG/media"
    mkdir -p "$config_root"

    local airvpn_key airvpn_psk airvpn_addr vpn_countries
    info "AirVPN WireGuard details (from AirVPN's config generator):"
    ask_required "  AIRVPN_PRIVATE_KEY" airvpn_key
    ask_required "  AIRVPN_PRESHARED_KEY" airvpn_psk
    ask_required "  AIRVPN_ADDRESS" airvpn_addr
    ask "  Preferred VPN server country" "Netherlands" vpn_countries

    write_env "$REPO_ROOT/${STACK_PATHS[media]}/.env" \
        "CONFIG_ROOT=$config_root" \
        "DATA_ROOT=$BASE_DATA" \
        "HDD1_ROOT=$BASE_HDD1" \
        "" \
        "TZ=$BASE_TZ" \
        "PGID=$BASE_PGID" \
        "UMASK=$BASE_UMASK" \
        "" \
        "AIRVPN_PRIVATE_KEY=$airvpn_key" \
        "AIRVPN_PRESHARED_KEY=$airvpn_psk" \
        "AIRVPN_ADDRESS=$airvpn_addr" \
        "VPN_SERVER_COUNTRIES=$vpn_countries" \
        "" \
        "SONARR_PORT=8989" \
        "RADARR_PORT=7878" \
        "PROWLARR_PORT=9696" \
        "FLARESOLVERR_PORT=8191" \
        "BAZARR_PORT=6767" \
        "QBIT_PORT=6902" \
        "QBIT_WEBUI_PORT=8080" \
        "JELLYSEERR_PORT=5055" \
        "JELLYFIN_PORT=8096" \
        "JELLYFIN_DISCOVERY_PORT=7359" \
        "WIZARR_PORT=5690" \
        "" \
        "SONARR_PUID=13001" \
        "RADARR_PUID=13002" \
        "PROWLARR_PUID=13006" \
        "QBIT_PUID=13007" \
        "JELLYSEERR_PUID=13012" \
        "JELLYFIN_PUID=1000" \
        "WIZARR_PUID=1000" \
        "WIZARR_PGID=1000" \
        "BAZARR_PUID=1000" \
        "BAZARR_PGID=1000" \
        "" \
        "WIZARR_DISABLE_BUILTIN_AUTH=false" \
        "LOG_LEVEL=info" \
        "LOG_HTML=false" \
        "CAPTCHA_SOLVER=none"

    info "Note: sonarr/radarr/prowlarr/flaresolverr/qbittorrent share gluetun's"
    info "network — inside them, reach each other via localhost, not container names."
}

setup_dashdot() {
    header "dashdot"
    local port items
    ask "Port to expose the dashboard on" "3006" port
    ask "Storage widget: items per page" "10" items
    write_env "$REPO_ROOT/${STACK_PATHS[dashdot]}/.env" \
        "PORT=$port" \
        "ITEMS_PER_PAGE=$items"
}

setup_forgejo() {
    header "forgejo"
    local config_root="$BASE_CONFIG/forgejo"
    mkdir -p "$config_root"

    local ssh_domain web_port ssh_port
    ask_required "SSH_DOMAIN (domain used in git clone URLs)" ssh_domain
    ask "Web UI port" "5000" web_port
    ask "SSH port" "223" ssh_port

    local mysql_root_pw mysql_user mysql_pw mysql_db
    ask "MySQL database name" "forgejo" mysql_db
    ask "MySQL user" "forgejo" mysql_user
    ask_secret "MySQL user password" mysql_pw
    ask_secret "MySQL root password" mysql_root_pw

    write_env "$REPO_ROOT/${STACK_PATHS[forgejo]}/.env" \
        "CONFIG_ROOT=$config_root" \
        "" \
        "FORGEJO_VERSION=14" \
        "MYSQL_VERSION=8" \
        "" \
        "FORGEJO_UID=1000" \
        "FORGEJO_GID=1000" \
        "WEB_PORT=$web_port" \
        "SSH_PORT=$ssh_port" \
        "SSH_DOMAIN=$ssh_domain" \
        "" \
        "MYSQL_ROOT_PASSWORD=$mysql_root_pw" \
        "MYSQL_USER=$mysql_user" \
        "MYSQL_PASSWORD=$mysql_pw" \
        "MYSQL_DATABASE=$mysql_db"
}

setup_immich() {
    header "immich"
    local immich_root="$BASE_DATA/immich"
    mkdir -p "$immich_root"

    local db_user db_pw db_name immich_port pub_url immich_url ipp_port
    ask "Postgres user" "immich" db_user
    ask_secret "Postgres password" db_pw
    ask "Postgres database name" "immich" db_name
    ask "Immich web port" "2283" immich_port
    ask "Public base URL (for shared links, e.g. https://photos.example.com)" "" pub_url
    ask "Internal Immich URL (used by immich-public-proxy)" "http://immich-server:2283" immich_url
    ask "Public proxy port" "2284" ipp_port

    write_env "$REPO_ROOT/${STACK_PATHS[immich]}/.env" \
        "DB_HOSTNAME=immich-database" \
        "DB_PORT=5432" \
        "DB_USERNAME=$db_user" \
        "DB_PASSWORD=$db_pw" \
        "DB_DATABASE_NAME=$db_name" \
        "" \
        "REDIS_HOSTNAME=immich-redis" \
        "REDIS_PORT=6379" \
        "REDIS_DBINDEX=0" \
        "" \
        "IMMICH_PORT=$immich_port" \
        "IMMICH_ROOT=$immich_root" \
        "" \
        "TZ=$BASE_TZ" \
        "" \
        "PUB_BASE_URL=$pub_url" \
        "IMMICH_URL=$immich_url" \
        "IPP_PORT=$ipp_port"
}

setup_vaultwarden() {
    header "vaultwarden"
    local vw_root="$BASE_CONFIG/vaultwarden"
    mkdir -p "$vw_root"

    local domain port
    ask_required "DOMAIN (full https URL vaultwarden will be served at)" domain
    ask "Port to expose vaultwarden on" "8081" port

    write_env "$REPO_ROOT/${STACK_PATHS[vaultwarden]}/.env" \
        "DOMAIN=$domain" \
        "VW_ROOT=$vw_root" \
        "VW_PORT=$port"
}

setup_invidious() {
    header "invidious"
    local port user pw hmac companion
    ask "Port" "5666" port
    ask_required "Admin username" user
    ask_secret "Admin password" pw 16
    ask_secret "HMAC_KEY" hmac 16
    ask_secret "Invidious companion key (COMPANION_KEY)" companion 16

    write_env "$REPO_ROOT/${STACK_PATHS[invidious]}/.env" \
        "PORT=$port" \
        "" \
        "USER=$user" \
        "PASSWORD=$pw" \
        "" \
        "HMAC_KEY=$hmac" \
        "COMPANION_KEY=$companion"
}

setup_syncyomi() {
    header "syncyomi"
    # This stack's compose file appends /syncyomi itself, so CONFIG_ROOT
    # points at the shared base directly rather than a dedicated subfolder.
    local port
    ask "Port" "8282" port

    write_env "$REPO_ROOT/${STACK_PATHS[syncyomi]}/.env" \
        "TZ=$BASE_TZ" \
        "CONFIG_ROOT=$BASE_CONFIG" \
        "PORT=$port"
}

setup_tailscale() {
    header "tailscale"
    # tailscale's compose file mounts ${CONFIG_ROOT}/ts, so CONFIG_ROOT here
    # is the shared base itself (see the CONFIG_ROOT gotcha in its README) —
    # not a per-stack subfolder, or state ends up nested one level too deep.
    local authkey hostname
    ask_required "TS_AUTHKEY (from https://console.tailscale.com/admin/settings/keys)" authkey
    ask "TS_HOSTNAME (name this node shows up as on your tailnet)" "$(hostname)" hostname

    write_env "$REPO_ROOT/${STACK_PATHS[tailscale]}/.env" \
        "TS_AUTHKEY=$authkey" \
        "TS_HOSTNAME=$hostname" \
        "" \
        "CONFIG_ROOT=$BASE_CONFIG"
}

setup_caddy() {
    header "caddy"
    local conf_path
    ask "Caddy config root (will contain conf/, certs/, site/)" "$BASE_CONFIG/caddy" conf_path
    mkdir -p "$conf_path/conf" "$conf_path/certs" "$conf_path/site"
    ok "created $conf_path/{conf,certs,site}"
    warn "Remember to put your Caddyfile in $conf_path/conf before starting."

    local container_name version
    ask "Container name" "caddy" container_name
    ask "Caddy image version" "2.9" version

    write_env "$REPO_ROOT/${STACK_PATHS[caddy]}/.env" \
        "CONTAINER_NAME=$container_name" \
        "CADDY_VERSION=$version" \
        "" \
        "CONF_PATH=$conf_path"
}

setup_newt() {
    header "newt (Pangolin tunnel client)"
    local endpoint id secret
    ask "PANGOLIN_ENDPOINT" "https://app.pangolin.net" endpoint
    ask_required "NEWT_ID (from your Pangolin site's setup page)" id
    ask_required "NEWT_SECRET (from your Pangolin site's setup page)" secret

    write_env "$REPO_ROOT/${STACK_PATHS[newt]}/.env" \
        "PANGOLIN_ENDPOINT=$endpoint" \
        "NEWT_ID=$id" \
        "NEWT_SECRET=$secret"
}

setup_watchtower() {
    header "watchtower"
    local interval label
    ask "Poll interval, seconds" "86400" interval
    if confirm "Only update containers explicitly labeled for watchtower?" "n"; then
        label="true"
    else
        label="false"
    fi

    write_env "$REPO_ROOT/${STACK_PATHS[watchtower]}/.env" \
        "WATCHTOWER_POLL_INTERVAL=$interval" \
        "WATCHTOWER_LABEL_ENABLE=$label"
}

# ---------------------------------------------------------------------------
# Step 3: run each selected stack's setup function
# ---------------------------------------------------------------------------
configure_selected() {
    for name in "${SELECTED[@]}"; do
        "setup_${name}"
    done
}

# ---------------------------------------------------------------------------
# Step 4: optionally bring stacks up
# ---------------------------------------------------------------------------
maybe_start() {
    header "Done configuring"
    if ! command -v docker >/dev/null 2>&1; then
        warn "docker not found on this machine — install Docker Engine + Compose, then run:"
        for name in "${SELECTED[@]}"; do
            info "  (cd ${STACK_PATHS[$name]} && docker compose up -d)"
        done
        return
    fi

    if confirm "Run 'docker compose up -d' for everything you just configured now?" "n"; then
        for name in "${SELECTED[@]}"; do
            header "Starting $name"
            (cd "$REPO_ROOT/${STACK_PATHS[$name]}" && docker compose up -d) || warn "$name failed to start — check its logs."
        done
    else
        info "Skipping. Start any stack later with:"
        for name in "${SELECTED[@]}"; do
            info "  (cd ${STACK_PATHS[$name]} && docker compose up -d)"
        done
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo -e "${BOLD}Docker stack installer${RESET}"
    info "This will create/update .env files in this repo. Existing ones are"
    info "backed up alongside themselves before being overwritten."

    choose_stacks
    setup_base
    configure_selected
    maybe_start

    header "Summary"
    ok "Shared settings: $BASE_ENV"
    for name in "${SELECTED[@]}"; do
        ok "$name -> ${STACK_PATHS[$name]}/.env"
    done
    echo
    info "Review each .env before relying on it in production, especially any"
    info "auto-generated passwords — they were printed above as they were made."
}

main
