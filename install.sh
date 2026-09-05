#!/usr/bin/env bash
# Bootstrap: install tools setup.sh needs, clone dotfiles, optionally run setup.sh.
#
# One-liner (after this file is on GitHub main):
#   curl -fsSL https://raw.githubusercontent.com/osmancoskun/dotfiles/main/install.sh | bash
#
# Options (pass after bash -s --):
#   --run-setup     Launch ~/.dotfiles/setup.sh when clone finishes
#   --help          Show usage

set -euo pipefail

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/osmancoskun/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
RUN_SETUP=0

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Install git/stow/curl/wget, clone dotfiles to ~/.dotfiles, then exit or run setup.sh.

Environment:
  DOTFILES_REPO_URL   Git remote (default: osmancoskun/dotfiles on GitHub)
  DOTFILES_DIR        Clone target (default: ~/.dotfiles)

Options:
  --run-setup         Run ./setup.sh after clone (interactive menu)
  -h, --help          Show this help

Examples:
  curl -fsSL https://raw.githubusercontent.com/osmancoskun/dotfiles/main/install.sh | bash
  curl -fsSL .../install.sh | bash -s -- --run-setup
EOF
}

log() { printf '%s\n' "$*"; }
info() { log "[INFO] $*"; }
ok() { log "[OK] $*"; }
err() { log "[ERROR] $*" >&2; }

while (($#)); do
    case "$1" in
        --run-setup) RUN_SETUP=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
    shift
done

detect_distro() {
    if [[ ! -f /etc/os-release ]]; then
        err "Cannot detect distribution (/etc/os-release missing)."
        exit 1
    fi
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
        fedora | rhel | centos) DISTRO=fedora ;;
        debian | ubuntu | linuxmint) DISTRO=debian ;;
        arch | manjaro) DISTRO=arch ;;
        *)
            err "Unsupported distribution: ${ID:-unknown}"
            exit 1
            ;;
    esac
    info "Detected: ${PRETTY_NAME:-$ID} ($DISTRO)"
}

install_bootstrap_packages() {
    local -a pkgs=(git stow curl wget)
    local -a need=()

    case "$DISTRO" in
        fedora)
            for p in "${pkgs[@]}"; do
                rpm -q "$p" &>/dev/null || need+=("$p")
            done
            if ((${#need[@]})); then
                info "Installing: ${need[*]}"
                sudo dnf install -y "${need[@]}"
            else
                info "Bootstrap packages already installed."
            fi
            ;;
        debian)
            for p in "${pkgs[@]}"; do
                dpkg -l "$p" 2>/dev/null | grep -q '^ii' || need+=("$p")
            done
            if ((${#need[@]})); then
                info "Installing: ${need[*]}"
                sudo apt-get update -y
                sudo apt-get install -y "${need[@]}"
            else
                info "Bootstrap packages already installed."
            fi
            ;;
        arch)
            for p in "${pkgs[@]}"; do
                pacman -Qi "$p" &>/dev/null || need+=("$p")
            done
            if ((${#need[@]})); then
                info "Installing: ${need[*]}"
                sudo pacman -S --noconfirm "${need[@]}"
            else
                info "Bootstrap packages already installed."
            fi
            ;;
    esac
    ok "Bootstrap packages ready."
}

clone_dotfiles() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Dotfiles already at $DOTFILES_DIR — pulling latest."
        git -C "$DOTFILES_DIR" pull --ff-only
    elif [[ -e "$DOTFILES_DIR" ]]; then
        err "$DOTFILES_DIR exists but is not a git repository."
        exit 1
    else
        info "Cloning $DOTFILES_REPO_URL → $DOTFILES_DIR"
        git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
    fi
    ok "Dotfiles at $DOTFILES_DIR"
}

main() {
    detect_distro
    install_bootstrap_packages
    clone_dotfiles

    if (( RUN_SETUP )); then
        info "Starting setup.sh …"
        exec bash "$DOTFILES_DIR/setup.sh"
    fi

    cat <<EOF

Done. Next steps:
  cd "$DOTFILES_DIR"
  ./setup.sh              # interactive menu
  ./setup.sh --help       # non-interactive env vars

Quick install (repo packages + shell configs):
  REPO_APPS=git,jq,ssh-askpass,cascadia-code,noto-sans-mono DOTFILES_APPS=zsh,chsh,omz,config ./setup.sh repo-install
  DOTFILES_APPS=zsh,chsh,omz,config ./setup.sh dotfiles-install
EOF
}

main "$@"
