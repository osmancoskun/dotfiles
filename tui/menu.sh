# Shell-only main menu (no dialog / no extra packages).

_TUI_LIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/tui-back.sh
source "$_TUI_LIB_ROOT/lib/tui-back.sh"

# Repo root (directory containing setup.sh and scripts/).
_tui_repo_root() {
    (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
}

# True if Sway is on PATH (enough to offer the Sway monitor option).
_tui_sway_available() {
    command -v sway &>/dev/null && command -v swaymsg &>/dev/null
}

tui_shell_main_menu() {
    # UI must go to stderr: stdout is captured by choice=$(...) in run_main_menu.
    clear >&2 2>/dev/null || true

    local sway_ok=0
    _tui_sway_available && sway_ok=1

    local dim strike rst
    if [[ -t 2 ]]; then
        dim=$'\033[2m'
        strike=$'\033[9m'
        rst=$'\033[0m'
    else
        dim=''
        strike=''
        rst=''
    fi

    {
        printf '%s\n' '' '  --- Setup ---' ''
        printf '%s\n' '  1) Update system'
        printf '%s\n' '  2) Repository packages (git, nc, net-tools, jq, Node.js, yarn, pnpm, …)'
        printf '%s\n' '  3) Third-party applications — vendor repos added only for apps you pick'
        printf '%s\n' '  4) Dotfiles & shell (Oh My Zsh, chsh to zsh)'
        if (( sway_ok )); then
            printf '%s\n' '  5) Monitors — Sway (layout / outputs)'
        else
            printf '%b\n' "  ${dim}${strike}5) Monitors — Sway (install sway to enable)${rst}"
        fi
        printf '%s\n' '  6) Wallpaper (Bing / NASA / Wikipedia — swaybg)'
        printf '%s\n' '' '  Q) Quit' ''
        printf '%b\n' "${dim}  In submenus: B then Enter → main menu${rst}" ''
    } >&2

    if (( sway_ok == 0 )); then
        printf '%b\n' "${dim}  (5 is dim + strikethrough: Sway not detected in PATH)${rst}" >&2
        printf '%s\n' '' >&2
    fi

    local raw
    if [[ -r /dev/tty ]]; then
        read -r -p "Choice [1/2/3/4/5/6/Q]: " raw </dev/tty
    else
        read -r -p "Choice [1/2/3/4/5/6/Q]: " raw
    fi
    raw="${raw:-Q}"
    raw="${raw//[$'\t\r\n']/}"
    case $raw in
        1) printf '%s\n' "1" ;;
        2) printf '%s\n' "2" ;;
        3) printf '%s\n' "3" ;;
        4) printf '%s\n' "4" ;;
        5) printf '%s\n' "5" ;;
        6) printf '%s\n' "6" ;;
        [Qq]) printf '%s\n' "Q" ;;
        [Bb]) printf '%s\n' "B" ;; # no-op: already at main menu (B is for submenus)
        *) printf '%s\n' "Q" ;;
    esac
}

tui_run_update_system() {
    print_header "UPDATE SYSTEM"
    set +e
    trap '' ERR
    update_system
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e

    if (( ec == 0 )); then
        print_success "System update finished."
    else
        print_warning "System update failed (exit $ec)."
    fi
    tui_wait_continue_or_back || return 0
}

tui_run_repo_packages() {
    print_header "REPOSITORY PACKAGES"
    set +e
    trap '' ERR
    repo_packages_pick_and_install
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e

    if (( ec == TUI_BACK_TO_MAIN )); then
        return 0
    fi
    if (( ec == 0 )); then
        print_success "Repository package step finished."
    else
        print_warning "Repository package step reported exit $ec."
    fi
    tui_wait_continue_or_back || return 0
}

tui_run_dotfiles_shell() {
    print_header "DOTFILES & SHELL"
    set +e
    trap '' ERR
    dotfiles_step_pick_and_run
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e

    if (( ec == TUI_BACK_TO_MAIN )); then
        return 0
    fi
    if (( ec == 0 )); then
        print_success "Dotfiles & shell step finished."
    else
        print_warning "Dotfiles & shell step reported exit $ec."
    fi
    tui_wait_continue_or_back || return 0
}

tui_run_desktop_apps() {
    print_header "THIRD-PARTY APPLICATIONS"
    set +e
    trap '' ERR
    desktop_apps_pick_and_install
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e

    if (( ec == TUI_BACK_TO_MAIN )); then
        return 0
    fi
    if (( ec == 0 )); then
        print_success "Third-party application step finished."
    else
        print_warning "Third-party application step reported exit $ec."
    fi
    tui_wait_continue_or_back || return 0
}

tui_run_monitors_setup() {
    print_header "MONITORS — SWAY"
    if ! _tui_sway_available; then
        print_warning "Sway is not installed (sway + swaymsg not found in PATH). Install sway from your distro, then choose 5 again."
        tui_wait_continue_or_back || return 0
        return 0
    fi
    local root
    root="$(_tui_repo_root)"
    set +e
    trap '' ERR
    bash "$root/scripts/setup/monitors.sh"
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e
    if (( ec == TUI_BACK_TO_MAIN )); then
        return 0
    fi
    if (( ec == 0 )); then
        print_success "Monitor setup script finished."
    else
        print_warning "Monitor setup script exited $ec."
    fi
    tui_wait_continue_or_back || return 0
}

tui_run_wallpaper_setup() {
    print_header "WALLPAPER"
    local root
    root="$(_tui_repo_root)"
    set +e
    trap '' ERR
    bash "$root/scripts/setup/wallpaper.sh"
    local ec=$?
    trap 'error_handler $LINENO' ERR
    set -e
    if (( ec == TUI_BACK_TO_MAIN )); then
        return 0
    fi
    if (( ec != 0 )); then
        print_warning "Wallpaper script exited $ec."
    fi
    tui_wait_continue_or_back || return 0
}

run_main_menu() {
    while true; do
        local choice
        choice=$(tui_shell_main_menu)
        choice="${choice//$'\r'/}"
        choice="${choice//$'\n'/}"

        case "${choice:-Q}" in
            1) tui_run_update_system ;;
            2) tui_run_repo_packages ;;
            3) tui_run_desktop_apps ;;
            4) tui_run_dotfiles_shell ;;
            5) tui_run_monitors_setup ;;
            6) tui_run_wallpaper_setup ;;
            B | b) ;; # already at main menu
            Q | q) break ;;
            *) ;;
        esac
    done
}
