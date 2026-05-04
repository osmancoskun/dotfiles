#!/usr/bin/env bash
# Interactive Sway monitor layout: list outputs (vendor/model), left-to-right order,
# per-output orientation + scale, then apply via swaymsg; optional permanent config.
#
# Requires: sway session, swaymsg, jq. Run from a terminal inside Sway.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/tui-back.sh
[[ -f "$ROOT/lib/tui-back.sh" ]] && source "$ROOT/lib/tui-back.sh"

info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
err() { printf '%s\n' "[ERROR] $*" >&2; }

if ! command -v swaymsg &>/dev/null; then
    err "swaymsg not found. Install sway and run this inside a Sway session."
    exit 1
fi
if ! command -v jq &>/dev/null; then
    err "jq not found. Install jq (e.g. from repository packages step)."
    exit 1
fi

if ! swaymsg -t get_outputs &>/dev/null; then
    err "Cannot talk to Sway (run this from a terminal inside Sway; check SWAYSOCK)."
    exit 1
fi

filter_outputs_json() {
    jq '[.[] | select(.name != null)
        | select(.name | ascii_downcase | contains("headless") | not)
        | select((.active == true) or (.current_mode != null))]' <<<"$1"
}

sort_outputs_lr_json() {
    jq 'sort_by((.rect.x // 0), .name)' <<<"$1"
}

display_label() {
    jq -r --arg n "$1" '
        .[] | select(.name == $n)
        | "\(.make // "—") / \(.model // "—")"
    ' <<<"$2"
}

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

valid_transform() {
    case $1 in
        normal | 90 | 180 | 270 | flipped | flipped-90 | flipped-180 | flipped-270) return 0 ;;
        *) return 1 ;;
    esac
}

scale_ok() {
    awk -v s="$1" 'BEGIN { if (s <= 0 || s > 10) exit 1; exit 0 }'
}

main() {
    info "Dotfiles repo: $ROOT"

    local raw filtered sorted count
    raw="$(swaymsg -t get_outputs -r)"
    filtered="$(filter_outputs_json "$raw")"
    count="$(jq 'length' <<<"$filtered")"

    if [[ "$count" == "0" ]]; then
        err "No usable outputs (nothing active / no current_mode, or only headless)."
        exit 1
    fi

    sorted="$(sort_outputs_lr_json "$filtered")"

    mapfile -t SORTED_NAMES < <(jq -r '.[].name' <<<"$sorted")

    printf '\n%s\n' "Detected outputs (left → right by current layout):" >&2
    local i name vendor_model
    for i in "${!SORTED_NAMES[@]}"; do
        name="${SORTED_NAMES[i]}"
        vendor_model=$(display_label "$name" "$sorted")
        printf '  %d) %-20s  %s\n' "$((i + 1))" "$name" "$vendor_model" >&2
    done

    printf '\n%s\n' "Left-to-right order: enter 1-based indices (spaces or commas)." >&2
    printf '%s\n' "Enter = keep the order printed above. B = back to main setup menu." >&2
    local order_line
    read_tty "> " order_line
    order_line="${order_line//,/ }"

    declare -a ORDERED_NAMES=()
    if [[ -z "${order_line// }" ]]; then
        ORDERED_NAMES=("${SORTED_NAMES[@]}")
        info "Using default order: ${ORDERED_NAMES[*]}"
    else
        declare -A seen=()
        local tok
        for tok in $order_line; do
            if ! [[ "$tok" =~ ^[0-9]+$ ]] || (( tok < 1 || tok > count )); then
                err "Invalid index in order: $tok (use 1–$count)"
                exit 1
            fi
            if [[ -n "${seen[$tok]:-}" ]]; then
                err "Duplicate index in order: $tok"
                exit 1
            fi
            seen[$tok]=1
            ORDERED_NAMES+=("${SORTED_NAMES[$((tok - 1))]}")
        done
        if ((${#ORDERED_NAMES[@]} != count)); then
            err "Order must list exactly $count distinct indices (you gave ${#ORDERED_NAMES[@]})."
            exit 1
        fi
    fi

    declare -A TRANSFORM_OF=()
    declare -A SCALE_OF=()

    local out cur_t cur_s label t_in s_in
    for out in "${ORDERED_NAMES[@]}"; do
        cur_t=$(jq -r --arg n "$out" '.[] | select(.name == $n) | .transform // "normal"' <<<"$sorted")
        cur_s=$(jq -r --arg n "$out" '.[] | select(.name == $n) | .scale // 1' <<<"$sorted")
        label=$(display_label "$out" "$sorted")

        printf '\n%s\n' "── Output: $out ($label) ──" >&2
        read_tty "  Orientation [normal|90|180|270|flipped|…] (Enter = $cur_t): " t_in
        t_in="${t_in:-$cur_t}"
        if ! valid_transform "$t_in"; then
            err "Invalid transform: $t_in"
            exit 1
        fi
        TRANSFORM_OF[$out]=$t_in

        read_tty "  Scale (Enter = $cur_s): " s_in
        s_in="${s_in:-$cur_s}"
        if ! [[ "$s_in" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            err "Invalid scale (use a number like 1 or 1.25): $s_in"
            exit 1
        fi
        if ! scale_ok "$s_in"; then
            err "Scale must be in (0, 10]: $s_in"
            exit 1
        fi
        SCALE_OF[$out]=$s_in
    done

    info "Applying mode, transform, and scale…"
    local o mode_str
    for o in "${ORDERED_NAMES[@]}"; do
        mode_str=$(jq -r --arg n "$o" '
            .[] | select(.name == $n) | .current_mode
            | if . == null then empty else "\(.width)x\(.height)" end
        ' <<<"$sorted")
        if [[ -n "$mode_str" && "$mode_str" != "null" ]]; then
            swaymsg "output $o mode $mode_str" >/dev/null 2>&1 || warn "mode not applied for $o (may already match)"
        fi
        swaymsg "output $o transform ${TRANSFORM_OF[$o]}" >/dev/null 2>&1 || warn "transform failed for $o"
        swaymsg "output $o scale ${SCALE_OF[$o]}" >/dev/null 2>&1 || warn "scale failed for $o"
    done

    sleep "${SWAY_LAYOUT_SETTLE_SEC:-0.35}"
    local after
    after="$(swaymsg -t get_outputs -r)"

    info "Placing outputs left → right…"
    local x=0 w
    for o in "${ORDERED_NAMES[@]}"; do
        w=$(jq -r --arg n "$o" '.[] | select(.name == $n) | .rect.width' <<<"$after")
        if [[ -z "$w" || "$w" == "null" ]]; then
            err "Could not read width for $o after layout change."
            exit 1
        fi
        swaymsg "output $o position ${x} 0" >/dev/null 2>&1 || warn "position failed for $o"
        x=$((x + w))
    done

    printf '\n%s\n' "Keep this layout how?" >&2
    printf '%s\n' "  B) Back to main setup menu" >&2
    printf '%s\n' "  1) This session only (no config file)" >&2
    printf '%s\n' "  2) Permanent — write ~/.config/sway/config.d/85-user-monitor-setup.conf" >&2
    local persist_choice
    read_tty "Choice [1/2] (default 1): " persist_choice
    persist_choice="${persist_choice:-1}"

    if [[ "$persist_choice" == "2" ]]; then
        local config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
        local sway_cfg_root="$config_root/sway"
        local cfgdir="$sway_cfg_root/config.d"
        if [[ -L "$sway_cfg_root" && ! -d "$sway_cfg_root" ]]; then
            local link_target
            link_target="$(readlink "$sway_cfg_root" 2>/dev/null || printf '%s' '?')"
            err "Cannot write monitor config: $sway_cfg_root is a broken symlink -> $link_target"
            err "Fix or remove that symlink, then run monitor setup again."
            exit 1
        fi
        if [[ -e "$sway_cfg_root" && ! -d "$sway_cfg_root" ]]; then
            err "Cannot write monitor config: $sway_cfg_root exists but is not a directory."
            exit 1
        fi
        if ! install -d "$cfgdir"; then
            err "Could not create monitor config directory: $cfgdir"
            exit 1
        fi
        local cfgfile="$cfgdir/85-user-monitor-setup.conf"
        local ts
        ts="$(date -Iseconds)"
        {
            printf '%s\n' "# Generated by dotfiles/scripts/setup/monitors.sh at $ts"
            printf '%s\n' "# Repo: $ROOT"
            x=0
            for o in "${ORDERED_NAMES[@]}"; do
                mode_str=$(jq -r --arg n "$o" '
                    .[] | select(.name == $n) | .current_mode
                    | if . == null then empty else "\(.width)x\(.height)" end
                ' <<<"$after")
                if [[ -n "$mode_str" && "$mode_str" != "null" ]]; then
                    printf 'output "%s" mode %s\n' "$o" "$mode_str"
                fi
                printf 'output "%s" transform %s\n' "$o" "${TRANSFORM_OF[$o]}"
                printf 'output "%s" scale %s\n' "$o" "${SCALE_OF[$o]}"
                w=$(jq -r --arg n "$o" '.[] | select(.name == $n) | .rect.width' <<<"$after")
                printf 'output "%s" position %s 0\n' "$o" "$x"
                x=$((x + w))
            done
        } >"$cfgfile"
        info "Wrote: $cfgfile"
        warn "Reload Sway config when ready: swaymsg reload   (re-reads all of ~/.config/sway/)"
    else
        info "Session-only layout (lost after Sway exit unless you save elsewhere)."
    fi

    printf '\n%s\n' "Done."
}

main "$@"
