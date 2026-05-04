# Oh My Zsh and common plugins.
# Expects: print_*.

# Install and setup Oh My Zsh
setup_oh_my_zsh() {
    print_header "SETTING UP OH MY ZSH"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed"
    else
        print_warning "Oh My Zsh already installed"
    fi

    # Install popular plugins
    print_info "Installing Oh My Zsh plugins..."

    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-autosuggestions
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        print_success "zsh-autosuggestions installed"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        print_success "zsh-syntax-highlighting installed"
    fi

    # zsh-history-substring-search
    if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ]]; then
        git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
        print_success "zsh-history-substring-search installed"
    fi

    # Ensure ~/.zshrc exists (e.g. if a previous setup step moved it away)
    if [[ ! -f "$HOME/.zshrc" ]] && [[ -f "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" ]]; then
        print_info "Creating ~/.zshrc from Oh My Zsh template..."
        cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc"
        print_success "~/.zshrc created"
    fi
}
