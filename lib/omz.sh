# Oh My Zsh and common plugins.
# Expects: print_*.

_omz_custom_dir() {
    printf '%s' "${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
}

_omz_is_complete() {
    [[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]
}

_omz_clone_plugin() {
    local name=$1
    local url=$2
    local dest="$(_omz_custom_dir)/plugins/$name"

    if [[ -d "$dest" ]]; then
        print_warning "$name already installed"
        return 0
    fi

    if ! git clone --depth 1 "$url" "$dest"; then
        print_error "Failed to clone $name"
        return 1
    fi
    print_success "$name installed"
}

_omz_install_core() {
    print_info "Installing Oh My Zsh..."
    if ! KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        print_error "Oh My Zsh install failed"
        return 1
    fi
    if ! _omz_is_complete; then
        print_error "Oh My Zsh install finished but oh-my-zsh.sh is missing"
        return 1
    fi
    print_success "Oh My Zsh installed"
    return 0
}

# Install Oh My Zsh and popular third-party plugins.
setup_oh_my_zsh() {
    print_header "SETTING UP OH MY ZSH"

    local preserved_plugins=""
    if [[ -d "$HOME/.oh-my-zsh" ]] && ! _omz_is_complete; then
        print_warning "Incomplete Oh My Zsh install detected (~/.oh-my-zsh exists but oh-my-zsh.sh is missing)"
        if [[ -d "$HOME/.oh-my-zsh/custom/plugins" ]]; then
            preserved_plugins="$(mktemp -d)"
            cp -a "$HOME/.oh-my-zsh/custom/plugins" "$preserved_plugins/"
            print_info "Preserved existing custom plugins"
        fi
        rm -rf "$HOME/.oh-my-zsh"
    fi

    if ! _omz_is_complete; then
        _omz_install_core || return 1
    else
        print_warning "Oh My Zsh already installed"
    fi

    if [[ -n "$preserved_plugins" && -d "$preserved_plugins/plugins" ]]; then
        mkdir -p "$(_omz_custom_dir)/plugins"
        cp -an "$preserved_plugins/plugins/." "$(_omz_custom_dir)/plugins/"
        rm -rf "$preserved_plugins"
        print_success "Restored preserved custom plugins"
    fi

    print_info "Installing Oh My Zsh plugins..."
    local fail=0
    _omz_clone_plugin zsh-autosuggestions \
        https://github.com/zsh-users/zsh-autosuggestions || fail=1
    _omz_clone_plugin zsh-syntax-highlighting \
        https://github.com/zsh-users/zsh-syntax-highlighting.git || fail=1
    _omz_clone_plugin zsh-history-substring-search \
        https://github.com/zsh-users/zsh-history-substring-search || fail=1

    if ! _omz_is_complete; then
        print_error "Oh My Zsh verification failed: ${HOME}/.oh-my-zsh/oh-my-zsh.sh not found"
        fail=1
    fi

    # Fallback template until dotfiles config is stowed (menu step "config").
    if [[ ! -f "$HOME/.zshrc" ]] && [[ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]]; then
        print_info "Creating temporary ~/.zshrc from Oh My Zsh template (replace via config step)..."
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
        print_success "~/.zshrc created from template"
    fi

    return "$fail"
}
