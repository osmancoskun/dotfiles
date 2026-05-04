#!/usr/bin/env bash
# Waybar custom: one whole-disk usage line; click cycles DISKS.
# Tooltip: plain lsblk --tree for listed disks (<tt> in emit_json).
# Always prints valid JSON (python3) when return-type is json.
set -uo pipefail
# GUI sessions often have a minimal PATH; these live in /usr/bin on Fedora etc.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$STATE_DIR/waybar-cycle-disk.idx"
mkdir -p "$STATE_DIR"

# Fixed whole disks first (lsblk TYPE disk), then removable (RM=1) auto-appended.
# Order = click cycle: internal list, then hot-plug USB etc. (no duplicates).
DISKS=(/dev/nvme1n1 /dev/nvme0n1)

removable_disk_paths() {
    lsblk -dn -o NAME,TYPE,RM 2>/dev/null | awk '
        $2 == "disk" && $3 == "1" {
            n = $1
            if (n ~ /^(zram|loop)/) next
            print "/dev/" n
        }'
}

# All whole-disk block devices (fallback if DISKS= paths missing or stale).
all_kernel_disks() {
    lsblk -dn -o NAME,TYPE,RM 2>/dev/null | awk '
        $2 == "disk" {
            n = $1
            if (n ~ /^(zram|loop)/) next
            print "/dev/" n
        }'
}

bytes_label() {
    awk -v b="${1:-0}" '
  function label(bb,   x, s) {
    if (bb + 0 <= 0) return "0"
    if (bb >= 1099511627776) {
      x = bb / 1099511627776
      if (x >= 10) return sprintf("%.0fTB", x)
      s = sprintf("%.1fTB", x)
      return (s == "0.0TB" ? "0" : s)
    }
    x = bb / 1073741824
    if (x >= 100) return sprintf("%.0fGB", x)
    if (x >= 10) return sprintf("%.0fGB", x)
    s = sprintf("%.1fGB", x)
    return (s == "0.0GB" ? "0" : s)
  }
  BEGIN { print label(b + 0) }'
}

human_pair() {
    local u=${1:-0} t=${2:-0}
    if ((10#${t:-0} <= 0)); then
        printf '?/?'
        return
    fi
    printf '%s/%s' "$(bytes_label "$u")" "$(bytes_label "$t")"
}

label_bytes() {
    local b=${1:-0}
    if ((10#${b:-0} <= 0)); then
        printf '?'
        return
    fi
    bytes_label "$b"
}

# One lsblk for all disks (stable column widths). COLUMNS widens non-tty output.
TOOLTIP_LSBLK_COLS="NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS"
TOOLTIP_LSBLK_COLS_FALLBACK="NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINT"
TOOLTIP_COLUMNS="${TOOLTIP_COLUMNS:-168}"

tooltip_lsblk_run() {
    local c="${TOOLTIP_COLUMNS:-168}" out
    ((${#@} == 0)) && return 1
    out=$(COLUMNS="$c" lsblk --tree -o "$TOOLTIP_LSBLK_COLS" "$@" 2>/dev/null) \
        || out=$(COLUMNS="$c" lsblk --tree -o "$TOOLTIP_LSBLK_COLS_FALLBACK" "$@" 2>/dev/null) \
        || return 1
    printf '%s' "$out"
}

disk_total_bytes() {
    local dev=$1
    local base=${dev##*/}
    local sectors sz
    if [[ -r "/sys/block/$base/size" ]]; then
        sectors=$(cat "/sys/block/$base/size")
        echo $((sectors * 512))
        return 0
    fi
    sz=$(lsblk -bdno SIZE "$dev" 2>/dev/null | head -n1) || return 1
    [[ "${sz:-0}" =~ ^[0-9]+$ && "$sz" -gt 0 ]] || return 1
    printf '%s\n' "$sz"
}

disk_used_sum_bytes() {
    local disk=$1
    local sum=0 mp u fst
    while read -r mp; do
        [[ -z "$mp" ]] && continue
        [[ "$mp" == "[SWAP]" ]] && continue
        fst=$(findmnt -n -o FSTYPE "$mp" 2>/dev/null || true)
        [[ "$fst" == "tmpfs" || "$fst" == "devtmpfs" || "$fst" == "squashfs" ]] && continue
        u=$(df -P -B1 "$mp" 2>/dev/null | awk 'NR==2 {print $3}')
        [[ -n "${u:-}" ]] && sum=$((sum + u))
    done < <(lsblk -nr -o MOUNTPOINT "$disk" 2>/dev/null | sort -u)
    echo "$sum"
}

valid_disks() {
    declare -A seen=()
    local d base
    for d in "${DISKS[@]}"; do
        [[ -b "$d" ]] || continue
        base="${d##*/}"
        seen[$base]=1
        printf '%s\n' "$d"
    done
    while read -r d; do
        [[ -z "$d" || ! -b "$d" ]] && continue
        base="${d##*/}"
        [[ -n "${seen[$base]:-}" ]] && continue
        seen[$base]=1
        printf '%s\n' "$d"
    done < <(removable_disk_paths)
    while read -r d; do
        [[ -z "$d" || ! -b "$d" ]] && continue
        base="${d##*/}"
        [[ -n "${seen[$base]:-}" ]] && continue
        seen[$base]=1
        printf '%s\n' "$d"
    done < <(all_kernel_disks)
}

line_for_disk() {
    local dev=$1 total_b used_b pair pct base
    base=${dev##*/}
    total_b=$(disk_total_bytes "$dev") || return 1
    [[ -z "${total_b:-}" || "$total_b" -le 0 ]] && return 1
    used_b=$(disk_used_sum_bytes "$dev")
    pair=$(human_pair "$used_b" "$total_b")
    pct=$(awk -v u="$used_b" -v t="$total_b" 'BEGIN { if (t<=0) print 0; else printf "%.0f", 100*u/t }')
    printf '%s' "$base $pair ${pct}%"
}

tooltip_all_disks() {
    local preferred=${1:-} devs=() d tip
    while read -r d; do
        [[ -z "$d" || ! -b "$d" ]] && continue
        devs+=("$d")
    done < <(valid_disks)
    if ((${#devs[@]} == 0)); then
        if [[ -n "$preferred" && -b "$preferred" ]]; then
            devs=("$preferred")
        else
            printf '%s' "(no disks: edit DISKS= or attach removable USB)"
            return
        fi
    fi
    tip=$(tooltip_lsblk_run "${devs[@]}") || tip="(lsblk failed; check block devices and util-linux)"
    printf '%s' "$tip"
}

emit_json() {
    local text=$1 tip=$2 tip_m
    export _WJSON_TEXT="$text" _WJSON_TIP="$tip"
    # Waybar draws tooltips with Pango: proportional font breaks space padding. Wrap in <tt> (needs "escape": false on custom/disks).
    python3 -c 'import json, os, html
t, p = os.environ["_WJSON_TEXT"], os.environ["_WJSON_TIP"]
markup = "<tt>" + html.escape(p, quote=False) + "</tt>"
print(json.dumps({"text": t, "tooltip": markup}, ensure_ascii=False))' 2>/dev/null && return 0
    tip_m=$(printf '%s' "$tip" | python3 -c 'import sys, html; p = sys.stdin.read(); print("<tt>" + html.escape(p, quote=False) + "</tt>")' 2>/dev/null) || tip_m=$tip
    if command -v jq &>/dev/null; then
        jq -n --arg text "$text" --arg tip "$tip_m" '{text: $text, tooltip: $tip}'
        return 0
    fi
    printf '{"text":"?","tooltip":"install python3"}\n'
}

if [[ "${1:-}" == cycle ]]; then
    mapfile -t V < <(valid_disks)
    n=${#V[@]}
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

mapfile -t V < <(valid_disks)
n=${#V[@]}
if ((n == 0)); then
    emit_json "—" "No disks (edit DISKS= or attach removable; RM=1 devices are auto-listed)."
    exit 0
fi

cur=0
[[ -f "$STATE_FILE" ]] && cur=$(cat "$STATE_FILE") || true
[[ "$cur" =~ ^[0-9]+$ ]] || cur=0
((cur >= n)) && cur=0

dev="${V[cur]}"
out=$(line_for_disk "$dev" || echo "—")
tip="$(tooltip_all_disks "$dev")"$'\n'"Click to cycle disk."
emit_json "$out" "$tip"
