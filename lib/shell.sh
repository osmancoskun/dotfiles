# Default shell (zsh).
# Expects: print_*, APP_DICT, install_package (packages.sh).

_login_shell() {
    getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7
}

_zsh_path() {
    command -v zsh 2>/dev/null || true
}

# Install zsh from the distro if missing.
ensure_zsh_installed() {
    print_header "ZSH"

    local zsh_bin
    zsh_bin="$(_zsh_path)"
    if [[ -n "$zsh_bin" ]]; then
        print_warning "zsh already installed ($("$zsh_bin" --version 2>/dev/null || echo "$zsh_bin"))"
        return 0
    fi

    if [[ -z "${APP_DICT[zsh]:-}" ]]; then
        print_error "No zsh package mapping for distro '$DISTRO'."
        return 1
    fi

    install_package "${APP_DICT[zsh]}" "zsh"
}

# Change default shell to zsh (uses passwd entry, not $SHELL).
change_shell() {
    print_header "CHANGING DEFAULT SHELL"

    local zsh_bin login_shell
    zsh_bin="$(_zsh_path)"
    if [[ -z "$zsh_bin" ]]; then
        print_error "zsh is not installed. Run the zsh install step first."
        return 1
    fi

    login_shell="$(_login_shell)"
    if [[ "$login_shell" == "$zsh_bin" ]]; then
        print_warning "Default login shell is already zsh ($zsh_bin)"
        return 0
    fi

    if ! grep -q "$zsh_bin" /etc/shells 2>/dev/null; then
        print_error "$zsh_bin is not listed in /etc/shells; cannot chsh."
        return 1
    fi

    print_info "Changing default login shell from '${login_shell:-unknown}' to $zsh_bin..."
    chsh -s "$zsh_bin"
    print_success "Default shell changed to zsh (log out and back in, or open a new login session)"
}
