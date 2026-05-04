# Clone/update dotfiles and GNU Stow into $HOME.
# Expects: DOTFILES_DIR, print_*.

# Setup dotfiles
setup_dotfiles() {
    print_header "SETTING UP DOTFILES"

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        print_info "Cloning dotfiles repository..."
        git clone https://github.com/osmancoskun/dotfiles.git "$DOTFILES_DIR"
        print_success "Dotfiles cloned"
    else
        print_info "Updating dotfiles repository..."
        cd "$DOTFILES_DIR"
        git pull
        print_success "Dotfiles updated"
    fi

    print_info "Stowing GNU Stow package 'home' into \$HOME..."
    cd "$DOTFILES_DIR" || return

    if ! command -v stow >/dev/null 2>&1; then
        print_warning "Stow not installed; install stow and re-run this step."
        return 1
    fi
    if [[ ! -d "$DOTFILES_DIR/home" ]]; then
        print_error "Missing stow package directory: $DOTFILES_DIR/home"
        return 1
    fi

    # home/ mirrors $HOME: .config/, .vimrc, Wallpapers/, etc.
    # stow merges into existing ~/.config (other apps keep their trees).
    if ! stow --restow --target="$HOME" home; then
        print_error "stow failed."
        return 1
    fi
    print_success "Dotfiles stowed (home → \$HOME). Conflicts: stow -n --adopt home (see stow(8))."
}
