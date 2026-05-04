#!/usr/bin/env bash
# Waybar custom: icon + iface name + IPv4; click cycles. Tooltip still shows kind (Ethernet, VPN, …).
# Valid JSON on stdout always (python3); waybar "return-type": "json" requires it.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$STATE_DIR/waybar-cycle-net.idx"
mkdir -p "$STATE_DIR"

list_ifaces() {
    # Anything not explicitly DOWN; skip lo and common virtual prefixes.
    ip -br link 2>/dev/null | awk '
      $1 != "lo" && $2 !~ /^DOWN$/ &&
      $1 !~ /^(docker|br-[0-9]|veth|virbr)/ { print $1 }
    ' || true
}

ipv4_for() {
    local dev=$1 out
    out=$(ip -4 -br addr show dev "$dev" 2>/dev/null | awk 'NR==1 {print $3}') || true
    out=${out%%/*}
    if [[ -z "$out" ]]; then
        printf '%s' "—"
    else
        printf '%s' "$out"
    fi
}

icon_for() {
    local dev=$1
    if command -v iw &>/dev/null && iw dev "$dev" info &>/dev/null 2>&1; then
        printf '%s' ""
        return
    fi
    case "$dev" in
        wl* | wlan*) printf '%s' "" ;;
        en* | eth* | usb*) printf '%s' "" ;;
        *) printf '%s' "" ;;
    esac
}

# Short label for the bar (not lo — callers skip lo).
kind_for() {
    local dev=$1
    case "$dev" in
        tailscale*) printf '%s' "Tailscale" ;;
        zt*) printf '%s' "ZeroTier" ;;
        wg*) printf '%s' "WireGuard" ;;
        tun* | tap*) printf '%s' "VPN" ;;
        ppp*) printf '%s' "PPP" ;;
        wl* | wlan*) printf '%s' "Wi-Fi" ;;
        en* | eth*) printf '%s' "Ethernet" ;;
        usb*) printf '%s' "Ethernet" ;;
        *) printf '%s' "$dev" ;;
    esac
}

tooltip_all() {
    local s="" dev ip k
    while read -r dev; do
        [[ -z "$dev" ]] && continue
        k=$(kind_for "$dev")
        ip=$(ipv4_for "$dev")
        s+="${dev} (${k}) → ${ip}"$'\n'
    done < <(list_ifaces)
    [[ -z "$s" ]] && s="(no interfaces)"
    printf '%s' "$s"
}

emit_json() {
    local text=$1 tip=$2 class=${3:-net-cycle}
    export _WJSON_TEXT="$text" _WJSON_TIP="$tip" _WJSON_CLASS="$class"
    python3 -c 'import json,os; print(json.dumps({"text":os.environ["_WJSON_TEXT"],"tooltip":os.environ["_WJSON_TIP"],"class":os.environ["_WJSON_CLASS"]}))' 2>/dev/null && return 0
    if command -v jq &>/dev/null; then
        jq -n --arg text "$text" --arg tip "$tip" --arg class "$class" \
            '{text: $text, tooltip: $tip, class: $class}'
        return 0
    fi
    printf '{"text":"?","tooltip":"install python3 for waybar JSON","class":"disconnected"}\n'
}

if [[ "${1:-}" == cycle ]]; then
    mapfile -t IFACES < <(list_ifaces)
    n=${#IFACES[@]}
    if ((n == 0)); then
        printf '0\n' >"$STATE_FILE"
        exit 0
    fi
    cur=0
    [[ -f "$STATE_FILE" ]] && cur=$(cat "$STATE_FILE") || true
    [[ "$cur" =~ ^[0-9]+$ ]] || cur=0
    ((cur >= n)) && cur=0
    cur=$(( (cur + 1) % n ))
    printf '%s\n' "$cur" >"$STATE_FILE"
    exit 0
fi

mapfile -t IFACES < <(list_ifaces)
n=${#IFACES[@]}
if ((n == 0)); then
    emit_json " offline" "No non-DOWN interfaces" "disconnected"
    exit 0
fi

cur=0
[[ -f "$STATE_FILE" ]] && cur=$(cat "$STATE_FILE") || true
[[ "$cur" =~ ^[0-9]+$ ]] || cur=0
((cur >= n)) && cur=0

dev="${IFACES[cur]}"
ip=$(ipv4_for "$dev")
ic=$(icon_for "$dev")
emit_json "${ic} ${dev} ${ip}" "$(tooltip_all)"$'\n'"Click to cycle interface." "net-cycle"
