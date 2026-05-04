#!/bin/bash

# Multi-Distribution Auto Setup Script
# Supports: Arch Linux, Debian/Ubuntu, Fedora
# Author: Generated for osmancoskun
# Version: 1.0

set -euo pipefail  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
DOTFILES_DIR="$HOME/.dotfiles"
LOG_FILE="$HOME/setup.log"

# Application dictionary - maps generic names to distro-specific package names
declare -A APP_DICT

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Print colored info messages
print_info() {
    log "${BLUE}[INFO]${NC} $1"
}

print_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    log "${RED}[ERROR]${NC} $1"
}

print_header() {
    log "${MAGENTA}========================================${NC}"
    log "${MAGENTA} $1${NC}"
    log "${MAGENTA}========================================${NC}"
}

# Error handler
error_handler() {
    print_error "Script failed at line $1. Exiting..."
    print_info "Check log file: $LOG_FILE"
    exit 1
}

trap 'error_handler $LINENO' ERR

# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/numbered-prompt.sh
source "$SCRIPT_DIR/lib/numbered-prompt.sh"
# shellcheck source=lib/tui-back.sh
source "$SCRIPT_DIR/lib/tui-back.sh"
# shellcheck source=lib/repo-packages.sh
source "$SCRIPT_DIR/lib/repo-packages.sh"
# shellcheck source=lib/repos.sh
source "$SCRIPT_DIR/lib/repos.sh"
# shellcheck source=lib/desktop-apps.sh
source "$SCRIPT_DIR/lib/desktop-apps.sh"
# shellcheck source=lib/node.sh
source "$SCRIPT_DIR/lib/node.sh"
# shellcheck source=lib/apps.sh
source "$SCRIPT_DIR/lib/apps.sh"
# shellcheck source=lib/omz.sh
source "$SCRIPT_DIR/lib/omz.sh"
# shellcheck source=lib/shell.sh
source "$SCRIPT_DIR/lib/shell.sh"
# shellcheck source=lib/dotfiles-step.sh
source "$SCRIPT_DIR/lib/dotfiles-step.sh"
# shellcheck source=tui/menu.sh
source "$SCRIPT_DIR/tui/menu.sh"

print_setup_usage() {
    printf '%s\n' "Usage: ${0##*/} [COMMAND]" "" \
        "  (no args)         Interactive menu (update … dotfiles & shell)" \
        "  repo | 2          Distro repository packages only (same as menu 2)" \
        "  repo-install      Non-interactive (set REPO_APPS=git,jq,...)" \
        "  desktop | apps | 3   Third-party apps; vendor .repo/.list added per selection" \
        "  apps-install      Non-interactive desktop apps (set DESKTOP_APPS=chrome,...)" \
        "  dotfiles | 4      Oh My Zsh + chsh (same as menu 4)" \
        "  dotfiles-install  Non-interactive (set DOTFILES_APPS=omz,chsh)" \
        "  monitors | 5      Sway monitor helper (same as menu 5; needs sway)" \
        "  wallpaper | 6     Interactive daily wallpaper setup (Bing/NASA/Wiki)" \
        "  waybar | 7        Link ~/.config/waybar from dotfiles (same as menu 7; needs sway)" \
        "  wallpaper-install Same as running scripts/setup/wallpaper.sh" \
        "  -h | --help       Show this help" "" \
        "REPO_APPS keys: git, openssh, nc, nettools, jq, htop, ripgrep, fd, bat, zip, tree, build, dnsutils, python, nodejs, yarn, pnpm" \
        "DESKTOP_APPS keys: chrome, vscode, warp, cloudflared, cursor, discord" \
        "DOTFILES_APPS keys: omz, chsh"
}

# Main execution
main() {
    case "${1:-}" in
        -h | --help)
            print_setup_usage
            exit 0
            ;;
    esac

    print_header "SETUP"
    print_info "Log file: $LOG_FILE"

    echo "Setup started at $(date)" >"$LOG_FILE"

    detect_distro
    init_app_dict

    case "${1:-menu}" in
        repo | 2)
            tui_run_repo_packages
            ;;
        repo-install)
            if [[ -z "${REPO_APPS:-}" ]]; then
                print_error "Set REPO_APPS (comma-separated keys). See: ${0##*/} --help"
                exit 1
            fi
            if ! repo_packages_set_want_from_csv "$REPO_APPS"; then
                print_error "No valid keys in REPO_APPS."
                exit 1
            fi
            set +e
            trap '' ERR
            repo_packages_install_selected
            local ec=$?
            trap 'error_handler $LINENO' ERR
            set -e
            exit "$ec"
            ;;
        desktop | apps | 3)
            tui_run_desktop_apps
            ;;
        apps-install)
            if [[ -z "${DESKTOP_APPS:-}" ]]; then
                print_error "Set DESKTOP_APPS (comma-separated keys). See: ${0##*/} --help"
                exit 1
            fi
            if ! desktop_apps_set_want_from_csv "$DESKTOP_APPS"; then
                print_error "No valid keys in DESKTOP_APPS."
                exit 1
            fi
            set +e
            trap '' ERR
            desktop_apps_install_selected
            local ec=$?
            trap 'error_handler $LINENO' ERR
            set -e
            exit "$ec"
            ;;
        dotfiles | 4)
            tui_run_dotfiles_shell
            ;;
        dotfiles-install)
            if [[ -z "${DOTFILES_APPS:-}" ]]; then
                print_error "Set DOTFILES_APPS (comma-separated: omz,chsh). See: ${0##*/} --help"
                exit 1
            fi
            if ! dotfiles_step_set_want_from_csv "$DOTFILES_APPS"; then
                print_error "No valid keys in DOTFILES_APPS."
                exit 1
            fi
            set +e
            trap '' ERR
            dotfiles_step_run_selected
            local ec2=$?
            trap 'error_handler $LINENO' ERR
            set -e
            exit "$ec2"
            ;;
        monitors | 5)
            tui_run_monitors_setup
            ;;
        wallpaper | 6)
            tui_run_wallpaper_setup
            ;;
        waybar | 7)
            tui_run_waybar_setup
            ;;
        wallpaper-install)
            set +e
            bash "$SCRIPT_DIR/scripts/setup/wallpaper.sh"
            local _wec=$?
            set -e
            ((_wec == TUI_BACK_TO_MAIN)) && exit 0
            exit "$_wec"
            ;;
        menu)
            run_main_menu
            ;;
        *)
            print_error "Unknown command: $1"
            print_setup_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
