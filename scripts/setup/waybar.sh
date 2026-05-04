#!/usr/bin/env bash
# Ensure Waybar config from dotfiles is linked at ~/.config/waybar.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/tui-back.sh
[[ -f "$ROOT/lib/tui-back.sh" ]] && source "$ROOT/lib/tui-back.sh"

info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
err() { printf '%s\n' "[ERROR] $*" >&2; }

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

main() {
    local src="$ROOT/home/.config/waybar"
    local dst="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"

    if [[ ! -d "$src" ]]; then
        err "Missing source directory: $src"
        exit 1
    fi

    install -d "$(dirname "$dst")"

    if [[ -L "$dst" ]]; then
        local cur_target
        cur_target="$(readlink "$dst" 2>/dev/null || true)"
        local src_real dst_real
        src_real="$(readlink -f "$src" 2>/dev/null || true)"
        dst_real="$(readlink -f "$dst" 2>/dev/null || true)"
        if [[ -n "$src_real" && -n "$dst_real" && "$dst_real" == "$src_real" ]]; then
            info "Waybar config already linked: $dst -> $src"
            exit 0
        fi
        warn "Replacing existing symlink: $dst -> $cur_target"
        ln -sfn "$src" "$dst"
        info "Waybar config linked: $dst -> $src"
        exit 0
    fi

    if [[ -e "$dst" ]]; then
        warn "Path exists and is not a symlink: $dst"
        warn "B = back to setup menu."
        local yn
        read_tty "Move it to backup and continue? [y/N]: " yn
        if [[ ! "$yn" =~ ^[Yy]$ ]]; then
            info "Skipped."
            exit 0
        fi
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        info "Moved existing path to: $backup"
    fi

    ln -s "$src" "$dst"
    info "Waybar config linked: $dst -> $src"
}

main "$@"
