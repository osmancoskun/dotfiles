#!/usr/bin/env bash
# Daily wallpapers: Bing / NASA APOD / Wikipedia (Wikimedia featured image).
# Filenames: DD-MM-YYYY-{bing|nasa|wikipedia}.<ext> — skip download if file exists.
#
# Env: ~/.config/sway/wallpaper-daily.env (see wallpaper-daily.env.example in repo)
# Usage: --daemon | --once | --prefetch-all | --list-today | --current-path | --apply FILE | --help

set -euo pipefail

# Default UA for NASA / Wikipedia. Bing uses curl_bing_get (browser-like UA) — see below.
UA='DotfilesWallpaper/1.0 (personal; +https://github.com/osmancoskun/dotfiles)'

ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/wallpaper-daily.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

# Bing often returns 403 to non-browser User-Agents; override in wallpaper-daily.env if needed.
WALLPAPER_UA_BING="${WALLPAPER_UA_BING:-Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36}"

WALLPAPER_PROVIDERS=${WALLPAPER_PROVIDERS:-bing}
WALLPAPER_ROTATE_SEC=${WALLPAPER_ROTATE_SEC:-0}
WALLPAPER_DATA_DIR=${WALLPAPER_DATA_DIR:-"$HOME/.local/share/wallpapers/daily"}
WALLPAPER_PREFETCH_ALL=${WALLPAPER_PREFETCH_ALL:-0}
NASA_API_KEY=${NASA_API_KEY:-DEMO_KEY}
WALLPAPER_ROTATE_SEC="${WALLPAPER_ROTATE_SEC//$'\r'/}"
WALLPAPER_PREFETCH_ALL="${WALLPAPER_PREFETCH_ALL//$'\r'/}"

# Hard caps for every curl (connect + total transfer). Override in wallpaper-daily.env if needed.
WALLPAPER_CURL_CONNECT_TIMEOUT=${WALLPAPER_CURL_CONNECT_TIMEOUT:-15}
WALLPAPER_CURL_MAX_TIME=${WALLPAPER_CURL_MAX_TIME:-120}
WALLPAPER_CURL_MAX_TIME_HEAD=${WALLPAPER_CURL_MAX_TIME_HEAD:-20}
WALLPAPER_CURL_RETRY_MAX_TIME=${WALLPAPER_CURL_RETRY_MAX_TIME:-45}

info() { printf '%s\n' "[wallpaper] $*"; }
warn() { printf '%s\n' "[wallpaper] WARN: $*" >&2; }

_curl_base=(--connect-timeout "$WALLPAPER_CURL_CONNECT_TIMEOUT" --max-time "$WALLPAPER_CURL_MAX_TIME" --retry 1 --retry-max-time "$WALLPAPER_CURL_RETRY_MAX_TIME")

curl_get() {
    curl -fsSL -A "$UA" "${_curl_base[@]}" "$@"
}

# Bing HPImageArchive and image CDN frequently reject non-browser UAs (HTTP 403).
curl_bing_get() {
    curl -fsSL -A "$WALLPAPER_UA_BING" "${_curl_base[@]}" "$@"
}

# HEAD / metadata only — short max-time so we never hang on a stuck server.
curl_head_get() {
    curl -fsS -A "$UA" --connect-timeout "$WALLPAPER_CURL_CONNECT_TIMEOUT" --max-time "$WALLPAPER_CURL_MAX_TIME_HEAD" -I "$@"
}

today_slug() {
    date +%d-%m-%Y
}

ymd_local() {
    date +%Y-%m-%d
}

ymd_path_local() {
    date +%Y/%m/%d
}

ext_from_ct() {
    case "${1,,}" in
        *image/jpeg* | *image/jpg*) echo jpg ;;
        *image/png*) echo png ;;
        *image/webp*) echo webp ;;
        *) echo "" ;;
    esac
}

ext_from_url() {
    local u=${1,,}
    case "$u" in
        *.jpg* | *.jpeg* | *.jpe*) echo jpg ;;
        *.png*) echo png ;;
        *.webp*) echo webp ;;
        *) echo "" ;;
    esac
}

download_bing() {
    local slug base full ext tmp out
    slug=$(today_slug)
    base=$(curl_bing_get "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US" | jq -r '.images[0].url // empty')
    [[ -z "$base" ]] && return 1
    full="https://www.bing.com${base}"
    full="${full//_1920x1080/_UHD}"
    full="${full//_1920x1200/_UHD}"
    ext=$(ext_from_url "$full")
    [[ -z "$ext" ]] && ext=jpg
    out="${WALLPAPER_DATA_DIR}/${slug}-bing.${ext}"
    [[ -f "$out" ]] && { printf '%s\n' "$out"; return 0; }
    mkdir -p "$WALLPAPER_DATA_DIR"
    tmp="${out}.part"
    curl_bing_get -o "$tmp" "$full"
    mv -f "$tmp" "$out"
    printf '%s\n' "$out"
}

download_nasa() {
    local slug date json media url ext ct tmp out
    slug=$(today_slug)
    date=$(ymd_local)
    json=$(curl_get "https://api.nasa.gov/planetary/apod?api_key=${NASA_API_KEY}&date=${date}") || return 1
    media=$(jq -r '.media_type // "image"' <<<"$json")
    if [[ "$media" == "image" ]]; then
        url=$(jq -r '.hdurl // .url // empty' <<<"$json")
    else
        url=$(jq -r '.thumbnail_url // .url // empty' <<<"$json")
    fi
    [[ -z "$url" || "$url" == "null" ]] && return 1
    ext=$(ext_from_url "$url")
    if [[ -z "$ext" ]]; then
        ct=$(curl_head_get -L "$url" 2>/dev/null | grep -i '^content-type:' | tail -1 | cut -d: -f2- | tr -d '\r' || true)
        ext=$(ext_from_ct "$ct")
        [[ -z "$ext" ]] && ext=jpg
    fi
    out="${WALLPAPER_DATA_DIR}/${slug}-nasa.${ext}"
    [[ -f "$out" ]] && { printf '%s\n' "$out"; return 0; }
    mkdir -p "$WALLPAPER_DATA_DIR"
    tmp="${out}.part"
    curl_get -L -o "$tmp" "$url"
    mv -f "$tmp" "$out"
    printf '%s\n' "$out"
}

download_wikipedia() {
    local slug path json url ext ct tmp out
    slug=$(today_slug)
    path=$(ymd_path_local)
    json=$(curl_get "https://api.wikimedia.org/feed/v1/wikipedia/en/featured/${path}") || return 1

    url=$(jq -r '
      [
        .image.thumbnail.source?,
        .image.image.source?,
        .mostread.articles[0].thumbnail.source?,
        .mostread.articles[0].originalimage.source?
      ]
      | map(select(. != null and . != "" and (startswith("http"))))
      | first // empty
    ' <<<"$json")

    [[ -z "$url" ]] && return 1
    ext=$(ext_from_url "$url")
    if [[ -z "$ext" ]]; then
        ct=$(curl_head_get -L "$url" 2>/dev/null | grep -i '^content-type:' | tail -1 | cut -d: -f2- | tr -d '\r' || true)
        ext=$(ext_from_ct "$ct")
        [[ -z "$ext" ]] && ext=jpg
    fi
    out="${WALLPAPER_DATA_DIR}/${slug}-wikipedia.${ext}"
    [[ -f "$out" ]] && { printf '%s\n' "$out"; return 0; }
    mkdir -p "$WALLPAPER_DATA_DIR"
    tmp="${out}.part"
    curl_get -L -o "$tmp" "$url"
    mv -f "$tmp" "$out"
    printf '%s\n' "$out"
}

ensure_download() {
    case $1 in
        bing) download_bing ;;
        nasa) download_nasa ;;
        wikipedia) download_wikipedia ;;
        *) warn "unknown provider: $1"; return 1 ;;
    esac
}

prefetch_all_today() {
    local p
    # Same provider list as daemon/--once (no extra sources beyond WALLPAPER_PROVIDERS).
    for p in "${P[@]}"; do
        if path=$(ensure_download "$p" 2>/dev/null); then
            info "cached OK: $path"
        else
            warn "prefetch failed: $p"
        fi
    done
    info "prefetch-all finished."
}

apply_wallpaper() {
    local f=$1
    [[ -f "$f" ]] || return 1
    if ! command -v swaybg &>/dev/null; then
        warn "swaybg not installed; cannot set wallpaper image."
        return 1
    fi
    pkill -x swaybg 2>/dev/null || true
    nohup swaybg -m fill -i "$f" >/dev/null 2>&1 &
    [[ "${WALLPAPER_QUIET:-0}" == "1" ]] || info "swaybg → $f"
}

# Cached wallpaper images: files for calendar today (DD-MM-YYYY-<provider>.<ext>), else newest
# matching *-(bing|nasa|wikipedia).* in WALLPAPER_DATA_DIR (so the menu still lists after date rollover).
list_today_wallpapers() {
    local slug d f base
    slug=$(today_slug)
    d="${WALLPAPER_DATA_DIR:-"$HOME/.local/share/wallpapers/daily"}"
    [[ -d "$d" ]] || return 0
    local matches=()
    shopt -s nullglob
    matches=("$d/${slug}-"*)
    shopt -u nullglob
    if ((${#matches[@]})); then
        printf '%s\n' "${matches[@]}" | LC_ALL=C sort
        return 0
    fi
    if command -v find &>/dev/null; then
        while IFS= read -r f; do
            [[ -f "$f" ]] || continue
            base=${f##*/}
            [[ "$base" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}-(bing|nasa|wikipedia)\.[A-Za-z0-9]+$ ]] || continue
            printf '%s\n' "$f"
        done < <(find "$d" -maxdepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -30 | cut -f2-)
    fi
}

# Path passed to swaybg -i for the newest swaybg process, if any (Linux /proc).
swaybg_image_path() {
    local pid line
    pid=$(pgrep -nx swaybg 2>/dev/null) || return 1
    [[ -z "$pid" ]] && return 1
    if [[ -r "/proc/$pid/cmdline" ]]; then
        line=$(tr '\0' ' ' <"/proc/$pid/cmdline")
    else
        line=$(ps -o args= -p "$pid" 2>/dev/null || true)
    fi
    [[ -z "$line" ]] && return 1
    if [[ "$line" =~ [[:space:]]-i[[:space:]]+([^[:space:]]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# Advisory lock: only one --daemon loop; reload starts a new process that replaces the old holder.
_W_DAEMON_LOCK="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-daily-daemon.lock"

# Kill other wallpaper-daily.sh --daemon PIDs (never $$). pgrep -f is flaky on some cmdlines; parse pgrep -af.
wallpaper_daemon_cleanup_peers() {
    local mypid line pid rest
    mypid=$$
    while read -r line; do
        [[ -z "$line" ]] && continue
        pid=${line%% *}
        rest=${line#* }
        [[ "$pid" == "$mypid" ]] && continue
        [[ "$rest" == *wallpaper-daily* && "$rest" == *--daemon* ]] || continue
        kill -TERM "$pid" 2>/dev/null || true
    done < <(pgrep -af "wallpaper-daily" 2>/dev/null || true)
    sleep 0.45
}

wallpaper_daemon_acquire_lock() {
    local n pid
    mkdir -p "$(dirname "$_W_DAEMON_LOCK")" 2>/dev/null || true
    exec 200>>"$_W_DAEMON_LOCK" || exit 1
    n=0
    while ! flock -n 200; do
        ((++n))
        ((n > 30)) && {
            warn "daemon: could not take lock; exiting (stale lock or stuck peer?)"
            exit 0
        }
        if command -v lsof &>/dev/null; then
            while read -r pid; do
                [[ -z "$pid" || "$pid" == "$$" ]] && continue
                kill -TERM "$pid" 2>/dev/null || true
            done < <(lsof -t "$_W_DAEMON_LOCK" 2>/dev/null || true)
        fi
        wallpaper_daemon_cleanup_peers
        sleep 0.4
    done
}

case "${1:-}" in
    -h | --help)
        printf '%s\n' "Usage: ${0##*/} --daemon | --once | --prefetch-all | --list-today | --current-path | --apply FILE" "" \
            "  --daemon         Single instance (flock + peer cleanup on reload); rotate per env" \
            "  --once           Apply first successful download from the provider list" \
            "  --prefetch-all   Download/cache today for each configured provider, then exit" \
            "  --list-today     Print cached paths (today's DD-MM-YYYY-* first; else newest dated bing/nasa/wikipedia files)" \
            "  --current-path   Print swaybg -i image path for newest swaybg (stdout), or exit 1" \
            "  --apply FILE     Set wallpaper to FILE (no download; same swaybg as daemon)" \
            "                   WALLPAPER_QUIET=1 hides the swaybg log line." "" \
            "Config: ${ENV_FILE}" \
            "Timeouts (seconds, optional in env): WALLPAPER_CURL_CONNECT_TIMEOUT WALLPAPER_CURL_MAX_TIME WALLPAPER_CURL_MAX_TIME_HEAD"
        exit 0
        ;;
    --list-today)
        list_today_wallpapers
        exit 0
        ;;
    --current-path)
        swaybg_image_path
        exit $?
        ;;
    --apply)
        shift
        _apply_target=${1:-}
        [[ -n "$_apply_target" ]] || {
            warn "--apply: missing file path"
            exit 1
        }
        [[ -f "$_apply_target" ]] || {
            warn "--apply: not a file: $_apply_target"
            exit 1
        }
        apply_wallpaper "$_apply_target" || exit 1
        exit 0
        ;;
esac

IFS=',' read -ra PROVIDERS <<<"${WALLPAPER_PROVIDERS// /,}"
declare -a P=()
for x in "${PROVIDERS[@]}"; do
    [[ -n "${x// }" ]] && P+=("${x// }")
done
((${#P[@]})) || {
    warn "No providers in WALLPAPER_PROVIDERS"
    exit 1
}

case "${1:-}" in
    --prefetch-all)
        prefetch_all_today
        ;;
    --once)
        for prov in "${P[@]}"; do
            if path=$(ensure_download "$prov" 2>/dev/null); then
                apply_wallpaper "$path"
                exit 0
            fi
            warn "download failed for $prov (trying next provider)"
        done
        warn "all providers failed for --once"
        exit 1
        ;;
    --daemon)
        wallpaper_daemon_acquire_lock
        info "daemon rotate=${WALLPAPER_ROTATE_SEC}s providers=${P[*]}"
        idx=0
        first=1
        while true; do
            if [[ "$WALLPAPER_PREFETCH_ALL" == "1" && "$first" == "1" ]]; then
                prefetch_all_today || true
            fi
            first=0
            prov="${P[$idx]}"
            if path=$(ensure_download "$prov" 2>/dev/null); then
                apply_wallpaper "$path" || true
            else
                warn "skip (download failed): $prov"
            fi
            if [[ "${WALLPAPER_ROTATE_SEC:-0}" =~ ^[0-9]+$ ]] && ((WALLPAPER_ROTATE_SEC > 0)); then
                idx=$(((idx + 1) % ${#P[@]}))
                sleep "$WALLPAPER_ROTATE_SEC"
            else
                info "WALLPAPER_ROTATE_SEC=0 — applied once, exiting daemon loop."
                exit 0
            fi
        done
        ;;
    *)
        printf '%s\n' "Usage: $0 --daemon | --once | --prefetch-all | --list-today | --current-path | --apply FILE  (try --help)" >&2
        exit 1
        ;;
esac
