# Shared "back to main menu" for setup TUI (menu item subflows).
# When sourced from setup.sh, TUI_BACK_TO_MAIN is used by lib/*.sh and tui/menu.sh.
# Standalone scripts (wallpaper.sh, monitors.sh) may source this file for the same code.

: "${TUI_BACK_TO_MAIN:=80}"

# Read one line into nameref; trimmed line "B" or "b" → return TUI_BACK_TO_MAIN.
tui_read_with_back() {
    local prompt=$1
    local -n _tui_rb_out=$2
    if [[ -r /dev/tty ]]; then
        read -r -p "$prompt" _tui_rb_out </dev/tty || true
    else
        read -r -p "$prompt" _tui_rb_out || true
    fi
    _tui_rb_out="${_tui_rb_out//[$'\t\r\n']/}"
    if [[ "${_tui_rb_out}" == [Bb] ]]; then
        return "$TUI_BACK_TO_MAIN"
    fi
    return 0
}

# After a step: Enter continues, B returns to main menu (return TUI_BACK_TO_MAIN).
tui_wait_continue_or_back() {
    local _
    if [[ -r /dev/tty ]]; then
        read -r -p "Press Enter to continue (B = main menu)... " _ </dev/tty || true
    else
        read -r -p "Press Enter to continue (B = main menu)... " _ || true
    fi
    _="${_//[$'\t\r\n']/}"
    if [[ "${_}" == [Bb] ]]; then
        return "$TUI_BACK_TO_MAIN"
    fi
    return 0
}
