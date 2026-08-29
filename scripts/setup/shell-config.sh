#!/usr/bin/env bash
# Link shell-related dotfiles (~/.zshrc, ~/.config/foot) from the repo.

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

_link_path() {
    local src=$1
    local dst=$2
    local label=$3

    if [[ ! -e "$src" ]]; then
        err "Missing source: $src"
        return 1
    fi

    install -d "$(dirname "$dst")"

    if [[ -L "$dst" ]]; then
        local src_real dst_real
        src_real="$(readlink -f "$src" 2>/dev/null || true)"
        dst_real="$(readlink -f "$dst" 2>/dev/null || true)"
        if [[ -n "$src_real" && -n "$dst_real" && "$dst_real" == "$src_real" ]]; then
            info "$label already linked: $dst"
            return 0
        fi
        warn "Replacing existing symlink: $dst"
        ln -sfn "$src" "$dst"
        info "$label linked: $dst -> $src"
        return 0
    fi

    if [[ -e "$dst" ]]; then
        warn "Path exists and is not a symlink: $dst"
        local yn="${SHELL_CONFIG_FORCE:-}"
        if [[ -z "$yn" && -r /dev/tty ]]; then
            warn "B = back to setup menu."
            read_tty "Move it to backup and continue? [y/N]: " yn
        elif [[ -z "$yn" ]]; then
            yn=y
            warn "Non-interactive: backing up and continuing."
        fi
        if [[ ! "$yn" =~ ^[Yy]$ ]]; then
            info "Skipped $label."
            return 0
        fi
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        info "Moved existing path to: $backup"
    fi

    ln -s "$src" "$dst"
    info "$label linked: $dst -> $src"
}

main() {
    local cfg_root="${XDG_CONFIG_HOME:-$HOME/.config}"
    local fail=0

    _link_path "$ROOT/home/.zshrc" "$HOME/.zshrc" ".zshrc" || fail=1
    _link_path "$ROOT/home/.config/foot/foot.ini" "$cfg_root/foot/foot.ini" "foot.ini" || fail=1

    exit "$fail"
}

main "$@"
