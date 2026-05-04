# Default shell (zsh).
# Expects: print_*.

# Change default shell to zsh
change_shell() {
    print_header "CHANGING DEFAULT SHELL"

    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
        print_info "Changing default shell to zsh..."
        chsh -s "$(command -v zsh)"
        print_success "Default shell changed to zsh (restart terminal to apply)"
    else
        print_warning "Default shell is already zsh"
    fi
}
