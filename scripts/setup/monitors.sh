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
        | select(.name | ascii_downcase | contains("headless") | not)]' <<<"$1"
}

sort_outputs_lr_json() {
    jq 'sort_by(
        (if .active == true then (.rect.x // 0) else 999999 end),
        .name
    )' <<<"$1"
}

output_is_active() {
    jq -e --arg n "$1" '.[] | select(.name == $n) | .active == true' <<<"$2" >/dev/null 2>&1
}

pick_output_mode() {
    jq -r --arg n "$1" '
        .[] | select(.name == $n) |
        if .current_mode != null then "\(.current_mode.width)x\(.current_mode.height)"
        elif ((.modes // []) | length) > 0 then
            (.modes | max_by(.width * .height) | "\(.width)x\(.height)")
        else empty end
    ' <<<"$2"
}

display_label() {
    jq -r --arg n "$1" '
        .[] | select(.name == $n)
        | "\(.make // "—") / \(.model // "—")"
    ' <<<"$2"
}

output_status_tag() {
    if output_is_active "$1" "$2"; then
        printf '%s' ""
    else
        printf '%s' " [disabled]"
    fi
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

is_disable_token() {
    local tok=$1 max=$2
    case "${tok,,}" in
        0 | - | x | disable | disabled | off | none | skip) return 0 ;;
    esac
    if [[ "$tok" =~ ^[0-9]+$ ]] && (( tok < 1 || tok > max )); then
        return 0
    fi
    return 1
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
        err "No outputs found (only headless or empty get_outputs)."
        exit 1
    fi

    sorted="$(sort_outputs_lr_json "$filtered")"

    mapfile -t SORTED_NAMES < <(jq -r '.[].name' <<<"$sorted")

    declare -a ACTIVE_NAMES=()
    local _n
    for _n in "${SORTED_NAMES[@]}"; do
        if output_is_active "$_n" "$sorted"; then
            ACTIVE_NAMES+=("$_n")
        fi
    done

    printf '\n%s\n' "Detected outputs (active left → right, then disabled):" >&2
    local i name vendor_model status
    for i in "${!SORTED_NAMES[@]}"; do
        name="${SORTED_NAMES[i]}"
        vendor_model=$(display_label "$name" "$sorted")
        status=$(output_status_tag "$name" "$sorted")
        printf '  %d) %-20s  %s%s\n' "$((i + 1))" "$name" "$vendor_model" "$status" >&2
    done

    printf '\n%s\n' "Left-to-right order: enter 1-based indices (spaces or commas)." >&2
    printf '%s\n' "Use 0 or an out-of-range number to skip/disable a slot." >&2
    printf '%s\n' "Monitors not listed are disabled. Enter = keep the order printed above." >&2
    printf '%s\n' "B = back to main setup menu." >&2
    local order_line
    read_tty "> " order_line
    order_line="${order_line//,/ }"

    declare -a ORDERED_NAMES=()
    if [[ -z "${order_line// }" ]]; then
        if ((${#ACTIVE_NAMES[@]})); then
            ORDERED_NAMES=("${ACTIVE_NAMES[@]}")
            info "Using default order (active only): ${ORDERED_NAMES[*]}"
        else
            ORDERED_NAMES=("${SORTED_NAMES[@]}")
            info "No active outputs; using full list: ${ORDERED_NAMES[*]}"
        fi
    else
        declare -A seen=()
        local tok
        for tok in $order_line; do
            if is_disable_token "$tok" "$count"; then
                if [[ "$tok" =~ ^[0-9]+$ ]] && (( tok > count )); then
                    warn "Index $tok not found — treating as disable"
                elif [[ "$tok" =~ ^[0-9]+$ ]] && (( tok == 0 )); then
                    info "Disable slot (0)"
                fi
                continue
            fi
            if ! [[ "$tok" =~ ^[0-9]+$ ]]; then
                err "Invalid token in order: $tok (use 1–$count, or 0/disable to skip)"
                exit 1
            fi
            if [[ -n "${seen[$tok]:-}" ]]; then
                err "Duplicate index in order: $tok"
                exit 1
            fi
            seen[$tok]=1
            ORDERED_NAMES+=("${SORTED_NAMES[$((tok - 1))]}")
        done
        if ((${#ORDERED_NAMES[@]} == 0)); then
            err "No monitors selected; order must include at least one valid index."
            exit 1
        fi
        info "Enabled outputs (left → right): ${ORDERED_NAMES[*]}"
    fi

    declare -a DISABLED_NAMES=()
    local _name _enabled
    for _name in "${SORTED_NAMES[@]}"; do
        _enabled=0
        for out in "${ORDERED_NAMES[@]}"; do
            if [[ "$out" == "$_name" ]]; then
                _enabled=1
                break
            fi
        done
        if (( _enabled == 0 )); then
            DISABLED_NAMES+=("$_name")
        fi
    done
    if ((${#DISABLED_NAMES[@]})); then
        info "Disabled outputs: ${DISABLED_NAMES[*]}"
    fi

    declare -A TRANSFORM_OF=()
    declare -A SCALE_OF=()
    declare -A WORKSPACES_OF=()
    declare -A WS_OWNER=()

    local out cur_t cur_s label t_in s_in ws_in ws_norm ws_tok out_active
    for out in "${ORDERED_NAMES[@]}"; do
        cur_t=$(jq -r --arg n "$out" '.[] | select(.name == $n) | .transform // "normal"' <<<"$sorted")
        cur_s=$(jq -r --arg n "$out" '.[] | select(.name == $n) | .scale // 1' <<<"$sorted")
        [[ "$cur_s" == "-1" ]] && cur_s=1
        label=$(display_label "$out" "$sorted")
        out_active=active
        if ! output_is_active "$out" "$sorted"; then
            out_active="disabled (will enable)"
        fi

        printf '\n%s\n' "── Output: $out ($label) [$out_active] ──" >&2
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

        read_tty "  Workspaces for this output (e.g. 1 2, comma/space; Enter = none): " ws_in
        ws_in="${ws_in//,/ }"
        ws_norm=""
        for ws_tok in $ws_in; do
            if ! [[ "$ws_tok" =~ ^[0-9]+$ ]] || (( ws_tok < 1 || ws_tok > 99 )); then
                err "Invalid workspace token '$ws_tok' for $out (use 1-99)."
                exit 1
            fi
            if [[ -n "${WS_OWNER[$ws_tok]:-}" && "${WS_OWNER[$ws_tok]}" != "$out" ]]; then
                err "Workspace $ws_tok assigned to multiple outputs: ${WS_OWNER[$ws_tok]} and $out."
                exit 1
            fi
            WS_OWNER[$ws_tok]="$out"
            if [[ -z "$ws_norm" ]]; then
                ws_norm="$ws_tok"
            else
                ws_norm="$ws_norm $ws_tok"
            fi
        done
        WORKSPACES_OF[$out]="$ws_norm"
    done

    info "Applying mode, transform, and scale…"
    local o mode_str
    for o in "${DISABLED_NAMES[@]}"; do
        swaymsg "output $o disable" >/dev/null 2>&1 || warn "disable failed for $o"
    done
    for o in "${ORDERED_NAMES[@]}"; do
        if ! output_is_active "$o" "$sorted"; then
            swaymsg "output $o enable" >/dev/null 2>&1 || warn "enable failed for $o"
        fi
        mode_str=$(pick_output_mode "$o" "$sorted")
        if [[ -z "$mode_str" ]]; then
            sleep 0.2
            after_enable="$(swaymsg -t get_outputs -r)"
            mode_str=$(pick_output_mode "$o" "$after_enable")
        fi
        if [[ -n "$mode_str" ]]; then
            swaymsg "output $o mode $mode_str" >/dev/null 2>&1 || warn "mode not applied for $o (may already match)"
        else
            warn "No mode found for $o; skipping mode (set manually if needed)"
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

    info "Applying workspace mapping…"
    local has_workspace_map=0 ws
    for o in "${ORDERED_NAMES[@]}"; do
        for ws in ${WORKSPACES_OF[$o]:-}; do
            has_workspace_map=1
            swaymsg "workspace number $ws, move workspace to output $o" >/dev/null 2>&1 || warn "workspace $ws mapping failed for $o"
        done
    done
    (( has_workspace_map == 0 )) && info "No workspace mapping selected."

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
            for o in "${DISABLED_NAMES[@]}"; do
                printf 'output "%s" disable\n' "$o"
            done
            x=0
            for o in "${ORDERED_NAMES[@]}"; do
                mode_str=$(pick_output_mode "$o" "$after")
                if [[ -z "$mode_str" ]]; then
                    mode_str=$(pick_output_mode "$o" "$sorted")
                fi
                if [[ -n "$mode_str" ]]; then
                    printf 'output "%s" mode %s\n' "$o" "$mode_str"
                fi
                printf 'output "%s" transform %s\n' "$o" "${TRANSFORM_OF[$o]}"
                printf 'output "%s" scale %s\n' "$o" "${SCALE_OF[$o]}"
                w=$(jq -r --arg n "$o" '.[] | select(.name == $n) | .rect.width' <<<"$after")
                printf 'output "%s" position %s 0\n' "$o" "$x"
                x=$((x + w))
            done
            has_workspace_map=0
            for o in "${ORDERED_NAMES[@]}"; do
                for ws in ${WORKSPACES_OF[$o]:-}; do
                    if (( has_workspace_map == 0 )); then
                        printf '\n# Workspace to output mapping\n'
                        has_workspace_map=1
                    fi
                    printf 'workspace number %s output %s\n' "$ws" "$o"
                done
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
