#!/usr/bin/env bash
# Interactive installer: daily wallpapers (Bing / NASA / Wikipedia) for Sway via swaybg.
# Runner installs only under ~/.config/sway (no separate stow/home package sync).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/tui-back.sh
[[ -f "$ROOT/lib/tui-back.sh" ]] && source "$ROOT/lib/tui-back.sh"

info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }

read_tty() {
    local prompt=$1
    local var=$2
    if [[ -r /dev/tty ]]; then
        read -r -p "$prompt" "$var" </dev/tty || true
    else
        read -r -p "$prompt" "$var" || true
    fi
    local _v
    _v="${!var-}"
    _v="${_v//[$'\t\r\n']/}"
    if [[ "${_v}" == [Bb] ]]; then
        exit "${TUI_BACK_TO_MAIN:-80}"
    fi
}

# True if wallpaper env and/or sway snippet already exists.
wallpaper_has_existing_config() {
    [[ -f "$_W_ENV" ]] || [[ -f "$_W_SNIP" ]]
}

edit_in_editor() {
    local f=$1
    if [[ ! -f "$f" ]]; then
        warn "Cannot edit (not a file): $f"
        return 1
    fi
    # First word of VISUAL/EDITOR (multi-arg editors like "vim -O" → use EDITOR=vim).
    local ed="${VISUAL:-${EDITOR:-nano}}"
    ed="${ed%% *}"
    if ! command -v "$ed" &>/dev/null; then
        ed=nano
        command -v nano &>/dev/null || {
            warn "No suitable editor (set EDITOR or install nano)."
            return 1
        }
    fi
    info "Opening: $f (editor: $ed)"
    if [[ -r /dev/tty ]]; then
        "$ed" "$f" </dev/tty >/dev/tty 2>&1 || true
    else
        "$ed" "$f" || true
    fi
}

# Print current env + snippet (no prompts). Used for mode 4 only.
wallpaper_show_config() {
    wallpaper_has_existing_config || return 0

    printf '\n%s\n' "— Current wallpaper configuration —" >&2
    if [[ -f "$_W_ENV" ]]; then
        printf '%s\n' "### $_W_ENV" >&2
        sed 's/^/  /' "$_W_ENV" >&2 || true
        printf '\n' >&2
    fi
    if [[ -f "$_W_SNIP" ]]; then
        printf '%s\n' "### $_W_SNIP" >&2
        sed 's/^/  /' "$_W_SNIP" >&2 || true
        printf '\n' >&2
    fi
}

# After showing config: offer to open each file in $EDITOR (mode 4 only).
wallpaper_prompt_config_edits() {
    local ans
    if [[ -f "$_W_ENV" ]]; then
        read_tty "Edit wallpaper-daily.env in \$EDITOR? [y/N]: " ans
        if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
            edit_in_editor "$_W_ENV"
        fi
    fi
    if [[ -f "$_W_SNIP" ]]; then
        read_tty "Edit Sway snippet (91-wallpaper-daily.conf)? [y/N]: " ans
        if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
            edit_in_editor "$_W_SNIP"
        fi
    fi
    return 0
}

# Overwrite dst with src: rm then cp (handles broken symlinks / same-path edge case).
install_file_force() {
    local src=$1 dst=$2
    if [[ ! -e "$src" ]] || [[ -d "$src" ]]; then
        warn "install_file_force: missing or not a file: $src"
        return 1
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ "$src" == "$dst" ]]; then
        local tmp
        tmp="$(mktemp)"
        cp -f "$src" "$tmp"
        mv -f "$tmp" "$dst"
    else
        rm -f "$dst"
        cp -f "$src" "$dst"
    fi
}

wallpaper_paths() {
    _W_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/sway"
    _W_SCRIPTS="$_W_CFG/scripts"
    _W_ENV="$_W_CFG/wallpaper-daily.env"
    # Canonical sources live next to this installer (always present in repo).
    _W_SRC_SCRIPT="$ROOT/scripts/setup/wallpaper-daily.sh"
    _W_DST_SCRIPT="$_W_SCRIPTS/wallpaper-daily.sh"
    _W_EX_SRC="$ROOT/scripts/setup/wallpaper-daily.env.example"
    _W_EX_DST="$_W_CFG/wallpaper-daily.env.example"
    _W_SNIP="$_W_CFG/config.d/91-wallpaper-daily.conf"
}

install_wallpaper_script_force() {
    if [[ ! -f "$_W_SRC_SCRIPT" ]]; then
        warn "Missing repo file: $_W_SRC_SCRIPT — your dotfiles checkout is incomplete."
        exit 1
    fi
    install_file_force "$_W_SRC_SCRIPT" "$_W_DST_SCRIPT"
    chmod +x "$_W_DST_SCRIPT"
    info "Runner installed (forced) → $_W_DST_SCRIPT"
}

# So --list-today / --apply exist before the menu prints (stale ~/.config copy used to yield an empty list).
wallpaper_sync_runner_if_needed() {
    [[ -f "$_W_SRC_SCRIPT" ]] || return 0
    if [[ ! -x "$_W_DST_SCRIPT" ]] || ! cmp -s "$_W_SRC_SCRIPT" "$_W_DST_SCRIPT" 2>/dev/null; then
        install_file_force "$_W_SRC_SCRIPT" "$_W_DST_SCRIPT"
        chmod +x "$_W_DST_SCRIPT"
        info "Wallpaper runner synced from repo (for menu listing and --apply)."
    fi
}

# Installed runner if present, else repo copy (both understand ~/.config env paths).
wallpaper_runner() {
    if [[ -x "$_W_DST_SCRIPT" ]]; then
        printf '%s\n' "$_W_DST_SCRIPT"
    else
        printf '%s\n' "$_W_SRC_SCRIPT"
    fi
}

# Today’s cache files + current swaybg -i path (stderr only).
wallpaper_show_today_and_current() {
    local runner cur f i
    runner="$(wallpaper_runner)"
    printf '\n%s\n' "— Cached images (today's DD-MM-YYYY-*; if none, newest dated files in cache) —" >&2
    local -a files=()
    mapfile -t files < <(bash "$runner" --list-today || true)
    if ((${#files[@]} > 0)); then
        i=1
        for f in "${files[@]}"; do
            printf '  %d) %s\n' "$i" "$f" >&2
            ((i++)) || true
        done
    else
        printf '%s\n' "  (none for today's date — run mode 3 or wait for the daemon)" >&2
    fi
    printf '\n%s\n' "— Current wallpaper (swaybg image file) —" >&2
    if cur=$(bash "$runner" --current-path 2>/dev/null); then
        if [[ -f "$cur" ]]; then
            printf '  %s\n' "$cur" >&2
        else
            printf '  %s (file not found on disk)\n' "$cur" >&2
        fi
    else
        printf '%s\n' "  (not detected — solid-colour swaybg, no swaybg, or not in a Sway session)" >&2
    fi
    printf '\n' >&2
}

run_apply_cached_pick() {
    wallpaper_sync_runner_if_needed
    local runner files pick_raw pick n
    runner="$(wallpaper_runner)"
    mapfile -t files < <(bash "$runner" --list-today || true)
    n=${#files[@]}
    if ((n == 0)); then
        warn "No cached files for today (see \"Today's cached images\" above)."
        return 1
    fi
    read_tty "Apply which number 1–$n from \"Today's cached images\" above (Enter = cancel): " pick_raw
    pick_raw="${pick_raw//[$'\t\r\n']/}"
    [[ -z "$pick_raw" ]] && {
        printf '%s\n' "Cancelled." >&2
        return 0
    }
    if ! [[ "$pick_raw" =~ ^[0-9]+$ ]] || ((pick_raw < 1 || pick_raw > n)); then
        warn "Invalid choice: $pick_raw"
        return 1
    fi
    pick=$((pick_raw - 1))
    set +e
    WALLPAPER_QUIET=1 bash "$runner" --apply "${files[pick]}"
    local ec=$?
    set -e
    if ((ec != 0)); then
        warn "--apply exited $ec (need swaybg and a running Sway session?)"
        return "$ec"
    fi
    return 0
}

install_env_example_force() {
    if [[ ! -f "$_W_EX_SRC" ]]; then
        warn "Example env not in repo (optional): $_W_EX_SRC — skipping copy."
        return 0
    fi
    install_file_force "$_W_EX_SRC" "$_W_EX_DST" || return 0
    info "Updated → $_W_EX_DST"
}

run_sync_only() {
    info "Repo: $ROOT"
    warn "Solid-colour swaybg in config.d can conflict with image wallpapers."
    install_wallpaper_script_force
    install_env_example_force
    info "Existing $_W_ENV left unchanged (if missing, run full setup mode 1 first)."
}

run_sync_and_once() {
    run_sync_only
    if [[ ! -f "$_W_ENV" ]]; then
        warn "No $_W_ENV — run mode 1 (full setup) first, then use mode 3 again."
        return 1
    fi
    info "Running: $_W_DST_SCRIPT --once"
    set +e
    bash "$_W_DST_SCRIPT" --once
    local ec=$?
    set -e
    if (( ec != 0 )); then
        warn "--once exited $ec (network / Sway / provider?)"
        return "$ec"
    fi
    info "Wallpaper applied (--once)."
}

run_full_setup() {
    info "Dotfiles repo: $ROOT"
    info "Requires: curl, jq, swaybg."
    warn "If you use exec swaybg -c … in config.d (solid colour), comment that out or wallpapers will fight."
    printf '%s\n' "At any prompt: B then Enter → main setup menu (when launched from ./setup.sh)." >&2

    printf '\n%s\n' "Providers (numbers separated by space or comma; 0 = all three):" >&2
    printf '%s\n' "  1) Bing daily image" >&2
    printf '%s\n' "  2) NASA Astronomy Picture of the Day" >&2
    printf '%s\n' "  3) Wikipedia / Wikimedia featured image of the day" >&2
    local sel
    read_tty "> " sel
    sel="${sel//,/ }"
    local providers_csv=""
    if [[ -z "${sel// }" || "$sel" == "0" ]]; then
        providers_csv="bing,nasa,wikipedia"
    else
        declare -A got=()
        local t
        for t in $sel; do
            case "$t" in
                1) got[bing]=1 ;;
                2) got[nasa]=1 ;;
                3) got[wikipedia]=1 ;;
                *) warn "Ignoring unknown choice: $t" ;;
            esac
        done
        local k
        declare -a picked=()
        for k in bing nasa wikipedia; do
            [[ -n "${got[$k]:-}" ]] && picked+=("$k")
        done
        if ((${#picked[@]} == 0)); then
            warn "No providers selected; defaulting to bing."
            providers_csv="bing"
        else
            providers_csv=$(IFS=,; echo "${picked[*]}")
        fi
    fi

    local rot
    read_tty "Rotation interval in seconds (0 = once at Sway start, no cycle; e.g. 300 = 5 min): " rot
    rot="${rot:-0}"
    if ! [[ "$rot" =~ ^[0-9]+$ ]]; then
        warn "Invalid number; using 0."
        rot=0
    fi

    local pf
    read_tty "Prefetch all providers on first daemon start only? [y/N]: " pf
    local prefetch=0
    [[ "${pf:-}" =~ ^[Yy]$ ]] && prefetch=1

    local nasa_key
    read_tty "NASA API key (Enter = DEMO_KEY): " nasa_key
    nasa_key="${nasa_key:-DEMO_KEY}"

    local data_dir
    data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers/daily"

    install_wallpaper_script_force
    install_env_example_force

    cat >"$_W_ENV" <<EOF
# Generated by scripts/setup/wallpaper.sh — edit freely
WALLPAPER_PROVIDERS=$providers_csv
WALLPAPER_ROTATE_SEC=$rot
WALLPAPER_DATA_DIR=$data_dir
WALLPAPER_PREFETCH_ALL=$prefetch
NASA_API_KEY=$nasa_key
EOF
    info "Wrote $_W_ENV"

    local add_snip
    read_tty "Add ~/.config/sway/config.d/91-wallpaper-daily.conf (daemon at Sway start)? [y/N]: " add_snip
    if [[ "${add_snip:-}" =~ ^[Yy]$ ]]; then
        mkdir -p "$_W_CFG/config.d"
        cat >"$_W_SNIP" <<'EOSNIP'
# Daily wallpaper daemon. Config: ~/.config/sway/wallpaper-daily.env
# Disable solid-colour swaybg in other snippets if it conflicts.
exec bash -c 'test -x "$HOME/.config/sway/scripts/wallpaper-daily.sh" && "$HOME/.config/sway/scripts/wallpaper-daily.sh" --daemon </dev/null >/dev/null 2>&1 &'
EOSNIP
        info "Wrote $_W_SNIP — run: swaymsg reload"
    else
        info "Skipped sway snippet. Manual: $_W_DST_SCRIPT --once  or  --daemon"
    fi

    printf '\n%s\n' "Done (full setup)."
}

main() {
    wallpaper_paths
    wallpaper_sync_runner_if_needed

    if ! wallpaper_has_existing_config; then
        info "No $_W_ENV or $_W_SNIP yet — full setup (mode 1) will create them."
    fi

    wallpaper_show_today_and_current

    printf '\n%s\n' "Wallpaper installer — choose mode:" >&2
    printf '%s\n' "  (B = back to main setup menu)" >&2
    printf '%s\n' "  1) Full setup (providers, rotation, NASA key, env, force-install script, optional sway snippet)" >&2
    printf '%s\n' "  2) Force latest script from repo only (removes old file/symlink, overwrites; keeps wallpaper-daily.env)" >&2
    printf '%s\n' "  3) Same as 2 + apply wallpaper now (--once; needs existing env)" >&2
    printf '%s\n' "  4) Show / edit configuration again only (env + 91 snippet), then exit" >&2
    printf '%s\n' "  5) Apply one of today's cached images only (no download; uses list above)" >&2
    local mode
    read_tty "Choice [1/2/3/4/5] (default 1): " mode
    mode="${mode:-1}"

    case "$mode" in
        2) run_sync_only ;;
        3) run_sync_and_once ;;
        4)
            wallpaper_show_config
            wallpaper_prompt_config_edits
            info "Done (configuration review)."
            ;;
        5) run_apply_cached_pick ;;
        1 | *) run_full_setup ;;
    esac
}

main "$@"
