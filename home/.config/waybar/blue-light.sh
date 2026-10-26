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

# systemctl disable removes this symlink when the unit file lives in the dotfiles repo.
ensure_unit() {
    if [[ -e "$UNIT_LINK" || -L "$UNIT_LINK" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "$UNIT_LINK")"
    ln -s ../../../.dotfiles/home/.config/systemd/user/wlsunset.service "$UNIT_LINK"
    systemctl --user daemon-reload
    systemctl --user enable "$UNIT" >/dev/null
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
