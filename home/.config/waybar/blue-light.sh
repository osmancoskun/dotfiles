#!/usr/bin/env bash
# Waybar custom: blue light strength in steps of 20%.
# Click: 0 -> 20 -> 40 -> 60 -> 80 -> 100 -> 0.
# 0% stops wlsunset. Any other step restarts the user unit at that temperature.
set -uo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

UNIT="wlsunset.service"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/wlsunset/wlsunset.env"
PERCENT_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/wlsunset/percent"
UNIT_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/wlsunset.service"

WLSUNSET_LOW=4000
WLSUNSET_HIGH=6500

if [[ -f "$CONFIG" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$CONFIG"
    set +a
fi

emit_json() {
    local text=$1 tip=$2 class=$3
    export _WJSON_TEXT="$text" _WJSON_TIP="$tip" _WJSON_CLASS="$class"
    python3 -c 'import json,os; print(json.dumps({"text":os.environ["_WJSON_TEXT"],"tooltip":os.environ["_WJSON_TIP"],"class":os.environ["_WJSON_CLASS"]}))' 2>/dev/null && return 0
    if command -v jq &>/dev/null; then
        jq -n --arg text "$text" --arg tip "$tip" --arg class "$class" \
            '{text: $text, tooltip: $tip, class: $class}'
        return 0
    fi
    printf '{"text":"?","tooltip":"install python3 for waybar JSON","class":"off"}\n'
}

# Waybar itself is a symlink into this repo. Resolve that, then point the
# user unit and ~/.config/wlsunset at the same tree. A hardcoded ~/.dotfiles
# path breaks when the clone lives somewhere else.
repo_config_dir() {
    (cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
}

# Return 0 when the symlink is created or replaced.
ensure_link() {
    local src=$1 dst=$2
    [[ -e "$src" ]] || return 1
    if [[ -L "$dst" ]]; then
        local src_real dst_real
        src_real="$(readlink -f "$src")"
        dst_real="$(readlink -f "$dst" 2>/dev/null || true)"
        if [[ "$src_real" == "$dst_real" ]]; then
            return 1
        fi
    elif [[ -e "$dst" ]]; then
        return 1
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
}

# systemctl disable removes the unit symlink when the unit file lives in the repo.
ensure_unit() {
    local root src config_src config_dst relinked=0
    root="$(repo_config_dir)"
    src="$root/systemd/user/wlsunset.service"
    config_src="$root/wlsunset"
    config_dst="${XDG_CONFIG_HOME:-$HOME/.config}/wlsunset"
    if ensure_link "$config_src" "$config_dst"; then
        relinked=1
    fi
    if ensure_link "$src" "$UNIT_LINK"; then
        relinked=1
        systemctl --user daemon-reload
        systemctl --user enable "$UNIT" >/dev/null
    fi
    if ((relinked)); then
        systemctl --user restart "$UNIT" >/dev/null 2>&1 || true
    fi
}

read_percent() {
    local p=0
    if [[ -f "$PERCENT_FILE" ]]; then
        p=$(tr -cd '0-9' <"$PERCENT_FILE" || true)
    fi
    [[ -n "$p" ]] || p=0
    if ((p > 100)); then
        p=100
    fi
    printf '%s' $((p / 20 * 20))
}

kelvin_for() {
    local percent=$1
    printf '%s' $((WLSUNSET_HIGH - (WLSUNSET_HIGH - WLSUNSET_LOW) * percent / 100))
}

cycle() {
    local cur next
    ensure_unit
    cur=$(read_percent)
    next=$((cur + 20))
    if ((next > 100)); then
        next=0
    fi
    mkdir -p "$(dirname "$PERCENT_FILE")"
    printf '%s\n' "$next" >"$PERCENT_FILE"
    if ((next == 0)); then
        systemctl --user stop "$UNIT" >/dev/null 2>&1 || true
    else
        systemctl --user restart "$UNIT" >/dev/null 2>&1 || true
    fi
}

if [[ "${1:-}" == "cycle" || "${1:-}" == "toggle" ]]; then
    cycle
else
    ensure_unit
fi

percent=$(read_percent)
temp=$(kelvin_for "$percent")
if ((percent == 0)); then
    emit_json " ${percent}%" "Blue light 0% (${temp}K). Click to set 20%." "off"
elif ((percent == 100)); then
    emit_json " ${percent}%" "Blue light 100% (${temp}K). Click to reset to 0%." "on"
else
    emit_json " ${percent}%" "Blue light ${percent}% (${temp}K). Click to add 20%." "on"
fi
